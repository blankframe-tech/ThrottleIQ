import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_location.dart';
import 'package:throttleiq/core/realtime/realtime_location_publisher.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/features/ride/presentation/providers/helpers/live_session_coordinator.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

import '../../core/realtime/in_memory_realtime_store.dart';

/// The partner live viewer's 1 Hz channel: `/live_shares/{token}` follows the
/// Firestore share's lifecycle exactly — created on share, written per fix,
/// removed on "Stop sharing now" — and thins the Firestore tick while it
/// carries position.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryRealtimeStore store;
  late RealtimeServices realtime;
  late _FakeFirestore firestore;
  late List<void Function(Timer)> periodicCallbacks;

  LiveSessionCoordinator coordinator({RealtimeServices? services}) =>
      LiveSessionCoordinator(
        firestore: firestore,
        publicLinkEnabled: () async => false,
        realtime: services ?? realtime,
        periodicTimerFactory: (_, cb) {
          periodicCallbacks.add(cb);
          return Timer(const Duration(days: 1), () {});
        },
      );

  Future<String> share(LiveSessionCoordinator c) async {
    final token = await c.enableLiveSharing(
      uid: 'alice',
      rideId: 'ride-1',
      lastLat: 23.81,
      lastLng: 90.41,
      currentSpeedMs: 5,
      crashDetected: false,
      status: RecordingStatus.active,
    );
    await pumpEventQueue();
    return token!;
  }

  const fix = LocationSample(lat: 23.8103, lng: 90.4125, speedMs: 9);

  setUp(() {
    store = InMemoryRealtimeStore();
    realtime = RealtimeServices(
      store: store,
      connections: RealtimeConnectionManager(store),
      health: RealtimeHealthMonitor(store),
    );
    firestore = _FakeFirestore();
    periodicCallbacks = [];
  });

  tearDown(() => realtime.dispose());

  test('sharing creates /live_shares/{token} owned by the rider, expiring in 24 h',
      () async {
    final c = coordinator();
    final token = await share(c);

    final node = store.valueAt('live_shares/$token') as Map;
    expect(node['uid'], 'alice');
    final expiresIn = DateTime.fromMillisecondsSinceEpoch(node['expiresAt'] as int)
        .difference(DateTime.now());
    expect(expiresIn.inHours, inInclusiveRange(23, 24));
    expect(token.length, greaterThanOrEqualTo(32),
        reason: 'database.rules.json refuses shorter tokens');
    expect(firestore.ops, contains('set liveSessions/$token'),
        reason: 'Firestore session is still the source of truth');
    expect(realtime.connections.holders, ['live-share']);
  });

  test('each fix offered while sharing reaches the location node with the next seq',
      () async {
    final c = coordinator();
    final token = await share(c);

    final seen = <int>[];
    final sub = store.watch('live_shares/$token/location').listen((raw) {
      final loc = RealtimeLocation.tryParse(raw);
      if (loc != null) seen.add(loc.seq);
    });
    c.offerLocation(fix);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [0]);
    final loc = RealtimeLocation.tryParse(
        store.valueAt('live_shares/$token/location'))!;
    expect(loc.lat, fix.lat);
    expect(loc.speedMs, fix.speedMs);
  });

  test('fixes before sharing is turned on go nowhere', () async {
    final c = coordinator();
    c.offerLocation(fix);
    await pumpEventQueue();
    expect(store.log, isEmpty);
  });

  test('"Stop sharing now" removes the node, even with writes still queued offline',
      () async {
    final c = coordinator();
    final token = await share(c);
    store.setOnline(false);
    c.offerLocation(fix);
    await c.stopSharingNow(uid: 'alice');
    c.offerLocation(fix);

    store.setOnline(true);
    await pumpEventQueue();
    expect(store.valueAt('live_shares/$token'), isNull);
    expect(store.log.last.kind, 'remove',
        reason: 'the revoke must be the last word on the node');
    expect(c.relay, isNull);
    await pumpEventQueue();
    expect(realtime.connections.holders, isEmpty,
        reason: 'socket lease released once the remove is acked');
  });

  test('re-sharing after a revoke uses a fresh node; the old one stays dead',
      () async {
    final c = coordinator();
    final first = await share(c);
    await c.stopSharingNow(uid: 'alice');
    final second = await share(c);

    expect(second, isNot(first));
    expect(store.valueAt('live_shares/$first'), isNull);
    expect((store.valueAt('live_shares/$second') as Map)['uid'], 'alice');
  });

  test('reset() (ride ended) tears the node down too', () async {
    final c = coordinator();
    final token = await share(c);
    c.reset();
    await pumpEventQueue();
    expect(store.valueAt('live_shares/$token'), isNull);
  });

  test('with RTDB unconfigured, sharing still works on Firestore alone',
      () async {
    final disabled = RealtimeServices.disabled();
    final c = coordinator(services: disabled);
    final token = await share(c);
    c.offerLocation(fix);
    expect(c.relay, isNull);
    expect(firestore.ops, contains('set liveSessions/$token'));
  });

  test('while RTDB carries position, only every 2nd Firestore tick is written',
      () async {
    final c = coordinator();
    await share(c);
    var ticks = 0;
    c.startPeriodicPublishing(onTick: () => ticks++);
    await pumpEventQueue(); // .info/connected → true

    for (var i = 0; i < 6; i++) {
      periodicCallbacks.single(_NoopTimer());
    }
    expect(ticks, 6 ~/ kFirestoreTickDivisorWhenRealtime);
  });

  test('when the socket is down past the grace, every Firestore tick is written',
      () async {
    // Zero grace: the drop below counts as "down past the grace" at once.
    final services = RealtimeServices(
      store: store,
      connections: RealtimeConnectionManager(store),
      health: RealtimeHealthMonitor(store, grace: Duration.zero),
    );
    final c = coordinator(services: services);
    await share(c);
    var ticks = 0;
    c.startPeriodicPublishing(onTick: () => ticks++);
    store.setOnline(false);
    await pumpEventQueue();

    for (var i = 0; i < 6; i++) {
      periodicCallbacks.single(_NoopTimer());
    }
    expect(services.transportNow(), RealtimeTransport.fallback);
    expect(ticks, 6);
  });
}

class _NoopTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => true;
  @override
  int get tick => 0;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  final List<String> ops = [];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollection(this, path);
}

// The project has no Firestore fake dependency; these two record the only
// calls LiveSessionCoordinator makes. `@sealed` is advisory.
// ignore: subtype_of_sealed_class
class _FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this._fs, this._path);
  final _FakeFirestore _fs;
  final String _path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _FakeDoc(_fs, '$_path/$id');
}

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _FakeDoc(this._fs, this._path);
  final _FakeFirestore _fs;
  final String _path;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async =>
      _fs.ops.add('set $_path');

  @override
  Future<void> update(Map<Object, Object?> data) async =>
      _fs.ops.add('update $_path');

  @override
  Future<void> delete() async => _fs.ops.add('delete $_path');
}
