import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/models/group_ride_model.dart';
import 'package:throttleiq/features/social/domain/entities/group_ride_entity.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_liveness.dart';
import 'package:throttleiq/features/social/presentation/providers/group_ride_providers.dart';

final now = DateTime(2026, 10, 1, 18);

GroupRideEntity ride({
  GroupRideStatus status = GroupRideStatus.active,
  required DateTime startedAt,
  DateTime? lastActiveAt,
}) =>
    GroupRideEntity(
      id: 'g1',
      creatorId: 'creator',
      creatorName: 'Creator',
      name: 'Evening ride',
      startTime: startedAt,
      createdAt: startedAt,
      status: status,
      lastActiveAt: lastActiveAt,
    );

void main() {
  group('isGroupRideLive', () {
    test('a freshly started active ride is live', () {
      final r = ride(startedAt: now.subtract(const Duration(minutes: 10)));
      expect(isGroupRideLive(r, now: now), isTrue);
      expect(isGroupRideAbandoned(r, now: now), isFalse);
    });

    test('a completed ride is never live, and not "abandoned" either', () {
      final r = ride(
          status: GroupRideStatus.completed,
          startedAt: now.subtract(const Duration(minutes: 10)));
      expect(isGroupRideLive(r, now: now), isFalse);
      expect(isGroupRideAbandoned(r, now: now), isFalse);
    });

    test(
        'an "active" ride from days ago with no heartbeat is stale — the '
        'Riding Now zombie cards', () {
      final r = ride(startedAt: now.subtract(const Duration(days: 3)));
      expect(isGroupRideLive(r, now: now), isFalse);
      expect(isGroupRideAbandoned(r, now: now), isTrue);
    });

    test('a long ride kept alive by its heartbeat stays live', () {
      final r = ride(
        startedAt: now.subtract(const Duration(hours: 9)),
        lastActiveAt: now.subtract(const Duration(minutes: 6)),
      );
      expect(isGroupRideLive(r, now: now), isTrue);
    });

    test('goes stale once the heartbeat is older than the cutoff', () {
      final r = ride(
        startedAt: now.subtract(const Duration(hours: 9)),
        lastActiveAt: now.subtract(kGroupRideInactiveCutoff),
      );
      expect(isGroupRideLive(r, now: now), isFalse);
    });

    test('lastActivity is the latest of start, create and heartbeat', () {
      final start = now.subtract(const Duration(hours: 2));
      expect(groupRideLastActivity(ride(startedAt: start)), start);
      final beat = now.subtract(const Duration(minutes: 1));
      expect(
          groupRideLastActivity(ride(startedAt: start, lastActiveAt: beat)),
          beat);
    });
  });

  group('GroupRideModel lastActiveAt', () {
    test('round-trips, and a new ride is written with a heartbeat', () {
      final model = GroupRideModel(
        id: 'g1',
        creatorId: 'c',
        creatorName: 'C',
        name: 'n',
        startTime: now,
        createdAt: now,
        status: 'active',
      );
      final written = model.toFirestore();
      expect(written['lastActiveAt'], now);
      final read = GroupRideModel.fromFirestore(written, 'g1').toEntity();
      expect(read.lastActiveAt, now);
    });

    test('copyWith keeps the join code and heartbeat', () {
      final e = GroupRideEntity(
        id: 'g1',
        creatorId: 'c',
        creatorName: 'C',
        name: 'n',
        startTime: now,
        createdAt: now,
        joinCode: 'ABC234',
        lastActiveAt: now,
      ).copyWith(members: const []);
      expect(e.joinCode, 'ABC234');
      expect(e.lastActiveAt, now);
    });
  });

  group('groupRideEffectFor', () {
    test('starting to ride starts the heartbeat', () {
      expect(groupRideEffectFor(wasRiding: false, isRiding: true),
          GroupRideRecordingEffect.startHeartbeat);
    });
    test('ending the recording finishes the group ride', () {
      expect(groupRideEffectFor(wasRiding: true, isRiding: false),
          GroupRideRecordingEffect.finish);
    });
    test('no change, no effect', () {
      expect(groupRideEffectFor(wasRiding: true, isRiding: true),
          GroupRideRecordingEffect.none);
      expect(groupRideEffectFor(wasRiding: false, isRiding: false),
          GroupRideRecordingEffect.none);
    });
  });
}
