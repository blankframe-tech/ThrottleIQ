import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_location.dart';
import 'package:throttleiq/core/realtime/realtime_location_publisher.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/features/social/data/repositories/group_ride_live_channel.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_positions.dart';

import '../../core/realtime/fake_clock.dart';
import '../../core/realtime/in_memory_realtime_store.dart';

/// Group rides' moving dots over RTDB: the channel's lifecycle writes, the
/// trust check, the merge with Firestore positions, and a multi-rider
/// writer → reader pipeline with delivery accounting.
void main() {
  late FakeClock clock;
  late InMemoryRealtimeStore store;
  late GroupRideLiveChannel channel;

  setUp(() {
    clock = FakeClock();
    store = InMemoryRealtimeStore(serverClock: clock.call);
    channel = GroupRideLiveChannel(RealtimeServices(
      store: store,
      connections: RealtimeConnectionManager(store),
      health: RealtimeHealthMonitor(store),
    ));
  });

  group('GroupRideLiveChannel', () {
    test('claimRide writes meta.creatorId', () async {
      await channel.claimRide('R', 'alice');
      expect(store.valueAt('group_rides/R/meta'), {'creatorId': 'alice'});
      expect(await channel.creatorOf('R'), 'alice');
    });

    test('ban marks the rider and drops their dot', () async {
      store.set('group_rides/R/locations/mallory',
          {'lat': 1, 'lng': 1, 'seq': 0, 'ts': 1});
      await channel.ban('R', 'mallory');
      expect(store.valueAt('group_rides/R/banned/mallory'), true);
      expect(store.valueAt('group_rides/R/locations/mallory'), isNull);
    });

    test('removeRide clears the whole node', () async {
      await channel.claimRide('R', 'alice');
      await channel.removeRide('R');
      expect(store.valueAt('group_rides/R'), isNull);
    });

    test('a refused write never throws into the Firestore flow it rides on',
        () async {
      store.denyPaths.add('group_rides/R');
      await expectLater(channel.claimRide('R', 'alice'), completes);
      await expectLater(channel.removeRide('R'), completes);
    });

    test('watchLocations skips malformed entries', () async {
      store.set('group_rides/R/locations/alice',
          {'lat': 23.8, 'lng': 90.4, 'seq': 3, 'ts': 1});
      store.set('group_rides/R/locations/junk', {'lat': 'x'});
      final first = await channel.watchLocations('R').first;
      expect(first.keys, ['alice']);
      expect(first['alice']!.seq, 3);
    });

    test('a kicked reader gets an error, not a silently frozen map', () async {
      final errors = <Object>[];
      final sub = channel
          .watchLocations('R')
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      store.revoke('group_rides/R');
      await pumpEventQueue();
      await sub.cancel();
      expect(errors, hasLength(1));
    });
  });

  group('isGroupRideChannelTrusted', () {
    test('only when RTDB meta names the Firestore creator', () {
      expect(
          isGroupRideChannelTrusted(
              realtimeCreatorId: 'alice', firestoreCreatorId: 'alice'),
          isTrue);
      expect(
          isGroupRideChannelTrusted(
              realtimeCreatorId: 'mallory', firestoreCreatorId: 'alice'),
          isFalse,
          reason: 'someone raced the creator to claim meta');
      expect(
          isGroupRideChannelTrusted(
              realtimeCreatorId: null, firestoreCreatorId: 'alice'),
          isFalse,
          reason: 'ride created by an older build');
    });
  });

  group('freshestMemberPosition', () {
    final t = DateTime.utc(2026, 10, 7, 9);
    RealtimeLocation rt(DateTime at) => RealtimeLocation(
        lat: 2, lng: 2, seq: 0, serverTime: at);
    Map<String, dynamic> fs(DateTime? at) =>
        {'lat': 1.0, 'lng': 1.0, 'timestamp': at == null ? null : Timestamp.fromDate(at)};

    test('newer RTDB beats a Firestore heartbeat', () {
      final p = freshestMemberPosition(
          realtime: rt(t.add(const Duration(seconds: 2))), firestore: fs(t))!;
      expect(p.source, MemberPositionSource.realtime);
      expect(p.position.latitude, 2);
    });

    test('newer Firestore beats a stale RTDB dot (rider fell back)', () {
      final p = freshestMemberPosition(
          realtime: rt(t), firestore: fs(t.add(const Duration(minutes: 1))))!;
      expect(p.source, MemberPositionSource.firestore);
    });

    test('an older build (Firestore only) still shows up', () {
      final p = freshestMemberPosition(firestore: fs(t))!;
      expect(p.source, MemberPositionSource.firestore);
    });

    test('in-flight Firestore write (null ts) falls back to the roster time',
        () {
      final p = freshestMemberPosition(
        firestore: fs(null),
        rosterUpdatedAt: t,
      )!;
      expect(p.updatedAt, t);
      expect(p.source, MemberPositionSource.firestore);
    });

    test('roster coordinates are the last resort; nothing at all is null', () {
      expect(
          freshestMemberPosition(rosterLat: 3, rosterLng: 3)!.source,
          MemberPositionSource.roster);
      expect(freshestMemberPosition(), isNull,
          reason: 'never published → off the map, not at 0,0');
    });
  });

  test('pipeline: three riders publishing at 2 s, one reader, nothing lost or reordered',
      () async {
    final riders = {
      'alice': channel.publisherFor('R', 'alice', clock: clock.call),
      'bob': channel.publisherFor('R', 'bob', clock: clock.call),
      'carol': channel.publisherFor('R', 'carol', clock: clock.call),
    };
    final stats = RealtimeDeliveryStats();
    final latest = <String, RealtimeLocation>{};
    final sub = channel.watchLocations('R').listen((locs) {
      for (final e in locs.entries) {
        if (stats.observe(e.key, e.value.seq)) latest[e.key] = e.value;
      }
    });

    // Everyone rides north ~11 m per second for a minute.
    for (var s = 0; s < 60; s++) {
      var i = 0;
      for (final p in riders.values) {
        p.offer(LocationSample(lat: 23.80 + s * 0.0001, lng: 90.40 + i++ * 0.01));
      }
      clock.elapse(const Duration(seconds: 1));
      await pumpEventQueue();
    }
    await sub.cancel();

    expect(stats.outOfOrder, 0);
    expect(stats.missed, 0);
    for (final entry in riders.entries) {
      expect(latest[entry.key]!.seq, entry.value.nextSeq - 1,
          reason: '${entry.key}: reader saw the final write');
    }
    // 2 s throttle → ~30 writes each over 60 s.
    expect(riders['alice']!.writesIssued, inInclusiveRange(29, 31));
  });

  test('pipeline: a rider that leaves disappears from everyone\'s map', () async {
    final alice = channel.publisherFor('R', 'alice');
    alice.offer(const LocationSample(lat: 23.8, lng: 90.4));
    await pumpEventQueue();
    expect((await channel.watchLocations('R').first).keys, ['alice']);

    await channel.removeLocation('R', 'alice');
    expect(await channel.watchLocations('R').first, isEmpty);
  });
}
