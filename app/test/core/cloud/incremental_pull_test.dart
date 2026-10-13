import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/cloud/pull_watermark.dart';
import 'package:throttleiq/core/cloud/sync_manager.dart';

/// §90.C7: incremental sync — full pull once per sign-in, then only
/// documents newer than the newest `syncedAt` already seen.
void main() {
  final t = DateTime.utc(2026, 10, 6, 12);

  group('PullWatermark.queryFloor', () {
    test('no mark yet: full pull', () {
      expect(PullWatermark.queryFloor(watermark: null, hasLocalRows: true),
          isNull);
    });

    test('a mark but an empty local table: full pull (cleared DB)', () {
      expect(PullWatermark.queryFloor(watermark: t, hasLocalRows: false),
          isNull);
    });

    test('a mark and local rows: incremental, with an overlap window', () {
      expect(PullWatermark.queryFloor(watermark: t, hasLocalRows: true),
          t.subtract(PullWatermark.overlap));
    });

    test('the epoch mark never underflows', () {
      expect(
        PullWatermark.queryFloor(
            watermark: PullWatermark.floorForUnstamped, hasLocalRows: true),
        PullWatermark.floorForUnstamped,
      );
    });
  });

  group('PullWatermark.advance', () {
    test('moves forward to the newest stamp seen', () {
      expect(
        PullWatermark.advance(
            current: t, seen: t.add(const Duration(hours: 1)), wasFullPull: false),
        t.add(const Duration(hours: 1)),
      );
    });

    test('never moves backwards', () {
      expect(
        PullWatermark.advance(
            current: t,
            seen: t.subtract(const Duration(minutes: 1)),
            wasFullPull: false),
        t,
      );
    });

    test('an incremental pull with nothing new keeps the mark', () {
      expect(PullWatermark.advance(current: t, seen: null, wasFullPull: false),
          t);
    });

    test('a full pull that saw no stamps still leaves a mark', () {
      expect(
          PullWatermark.advance(current: null, seen: null, wasFullPull: true),
          PullWatermark.floorForUnstamped);
    });
  });

  group('PullWatermark persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is per rider and per collection, and clears on sign-out', () async {
      await PullWatermark.write('alice', 'rides', t);
      await PullWatermark.write('bob', 'rides', t.add(const Duration(days: 1)));
      await PullWatermark.write('alice', 'bikes', t);

      expect(await PullWatermark.read('alice', 'rides'), t);
      expect(await PullWatermark.read('alice', 'maintenance'), isNull);

      await PullWatermark.clear('alice');
      expect(await PullWatermark.read('alice', 'rides'), isNull);
      expect(await PullWatermark.read('alice', 'bikes'), isNull);
      expect(await PullWatermark.read('bob', 'rides'),
          t.add(const Duration(days: 1)));
    });
  });

  group('CloudRepository.newestSyncedAt', () {
    test('takes the newest server timestamp, ignoring unstamped docs', () {
      final newest = CloudRepository.newestSyncedAt([
        {'syncedAt': Timestamp.fromDate(t)},
        {'id': 'legacy-without-syncedAt'},
        {'syncedAt': Timestamp.fromDate(t.add(const Duration(seconds: 5)))},
      ]);
      expect(newest!.isAtSameMomentAs(t.add(const Duration(seconds: 5))),
          isTrue);
    });

    test('null when nothing is stamped', () {
      expect(CloudRepository.newestSyncedAt([{}]), isNull);
    });
  });

  group('SyncManager.connectivitySyncDelay (30 s throttle)', () {
    test('first trigger runs immediately', () {
      expect(
          SyncManager.connectivitySyncDelay(lastSyncStartedAt: null, now: t),
          Duration.zero);
    });

    test('a flap 10 s after a sync waits out the rest of the window', () {
      expect(
        SyncManager.connectivitySyncDelay(
            lastSyncStartedAt: t, now: t.add(const Duration(seconds: 10))),
        const Duration(seconds: 20),
      );
    });

    test('after the window, runs immediately', () {
      expect(
        SyncManager.connectivitySyncDelay(
            lastSyncStartedAt: t, now: t.add(const Duration(seconds: 31))),
        Duration.zero,
      );
    });

    test('a clock that went backwards does not stall sync', () {
      expect(
        SyncManager.connectivitySyncDelay(
            lastSyncStartedAt: t, now: t.subtract(const Duration(minutes: 5))),
        Duration.zero,
      );
    });
  });

  // issues §101.C3: bikes and rides used to save the snapshot's newest
  // syncedAt even when a doc failed to insert, so that doc was never asked
  // for again until a full pull.
  group('CloudRepository.markShortOfFailures', () {
    test('no failure: the newest stamp seen', () {
      expect(CloudRepository.markShortOfFailures(t, null), t);
    });

    test('a failure: just short of the failed doc', () {
      final failed = t.subtract(const Duration(hours: 1));
      expect(CloudRepository.markShortOfFailures(t, failed),
          failed.subtract(const Duration(milliseconds: 1)));
    });

    test('nothing seen and nothing failed: null', () {
      expect(CloudRepository.markShortOfFailures(null, null), isNull);
    });

    test('earlierFailure keeps the earliest failed stamp', () {
      final early = t.subtract(const Duration(hours: 2));
      final late = t.subtract(const Duration(hours: 1));
      var first = CloudRepository.earlierFailure(
          null, {'syncedAt': Timestamp.fromDate(late)});
      first = CloudRepository.earlierFailure(
          first, {'syncedAt': Timestamp.fromDate(early)});
      first = CloudRepository.earlierFailure(
          first, {'syncedAt': Timestamp.fromDate(t)});
      expect(first!.isAtSameMomentAs(early), isTrue);
      expect(
          CloudRepository.markShortOfFailures(t, first)!.isAtSameMomentAs(
              early.subtract(const Duration(milliseconds: 1))),
          isTrue);
    });

    test('a failed doc without a stamp does not move the mark', () {
      expect(CloudRepository.earlierFailure(null, {'id': 'x'}), isNull);
    });
  });
}
