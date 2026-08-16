import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/auto_ride_reconciler.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';

/// Metres per degree of latitude, near enough for synthetic fixtures.
const _mPerDegLat = 111320.0;

/// Builds a straight-line northbound journey at a constant speed.
List<StagedFix> _journey({
  required double speedMs,
  required int seconds,
  DateTime? start,
  double accuracyM = 5,
  int intervalSeconds = 1,
}) {
  final t0 = start ?? DateTime(2026, 8, 16, 9);
  final fixes = <StagedFix>[];
  var lat = 23.8103; // Dhaka
  const lng = 90.4125;
  for (var s = 0; s <= seconds; s += intervalSeconds) {
    fixes.add((
      timestamp: t0.add(Duration(seconds: s)),
      lat: lat,
      lng: lng,
      speedMs: speedMs,
      accuracyM: accuracyM,
      altitudeM: 10.0,
      headingDeg: 0.0,
    ));
    lat += (speedMs * intervalSeconds) / _mPerDegLat;
  }
  return fixes;
}

void main() {
  late AutoRideReconciler reconciler;

  setUp(() => reconciler = AutoRideReconciler());

  group('rejection', () {
    test('rejects a detection with too few fixes', () {
      final outcome = reconciler.reconcile(_journey(speedMs: 11, seconds: 5));
      expect(outcome.isAccepted, isFalse);
      expect(outcome.rejectionReason, ReconcileRejection.tooFewFixes);
    });

    test('rejects walking pace — wheeling the bike out is not a ride', () {
      final outcome = reconciler.reconcile(_journey(speedMs: 1.4, seconds: 600));
      expect(outcome.isAccepted, isFalse);
      expect(outcome.rejectionReason, ReconcileRejection.tooSlow);
    });

    test('rejects a stationary phone that never moved', () {
      final outcome = reconciler.reconcile(_journey(speedMs: 0, seconds: 600));
      expect(outcome.isAccepted, isFalse);
      expect(outcome.rejectionReason, ReconcileRejection.noMovement);
    });

    test('rejects a short hop below the distance floor', () {
      // 6 m/s for 30 s ≈ 180 m — over the speed floor, under the distance one.
      final outcome = reconciler.reconcile(_journey(speedMs: 6, seconds: 30));
      expect(outcome.isAccepted, isFalse);
      // 31 fixes clears minFixes, so this must fail on distance, not count.
      expect(outcome.rejectionReason, ReconcileRejection.tooShortDistance);
    });

    test('drops fixes worse than the accuracy gate before anything else', () {
      // Same journey, but every fix is beyond SensorConstants.maxGpsAccuracyM.
      // Nothing survives the gate, so it can't have enough fixes to be a ride.
      final outcome = reconciler.reconcile(
        _journey(speedMs: 11, seconds: 600, accuracyM: 80),
      );
      expect(outcome.isAccepted, isFalse);
      expect(outcome.rejectionReason, ReconcileRejection.tooFewFixes);
    });
  });

  group('acceptance', () {
    test('rebuilds a realistic commute', () {
      // 40 km/h for five minutes ≈ 3.3 km.
      final outcome = reconciler.reconcile(
        _journey(speedMs: 11.1, seconds: 300),
      );

      expect(outcome.isAccepted, isTrue);
      final ride = outcome.ride!;

      expect(ride.durationSeconds, 300);
      expect(ride.distanceM, closeTo(3330, 60));
      expect(ride.maxSpeedMs, closeTo(11.1, 0.01));
      // Constant speed above the moving threshold for the whole journey.
      expect(ride.movingSeconds, 300);
      // distance ÷ moving time, matching average_speed.dart.
      expect(ride.avgSpeedMs, closeTo(11.1, 0.3));
      expect(ride.points, isNotEmpty);
      expect(ride.crashSuspected, isFalse);
    });

    test('thins persisted points on a steady stretch but keeps every metre',
        () {
      final outcome = reconciler.reconcile(
        _journey(speedMs: 11.1, seconds: 300),
      );
      final ride = outcome.ride!;

      // RecordingCadencePolicy only ever thins what is WRITTEN. Distance is
      // summed from every fix, so a thinned point list must not shrink it —
      // this is the invariant the live path holds and the replay must too.
      expect(ride.points.length, lessThan(301));
      expect(ride.distanceM, closeTo(3330, 60));
    });

    test('point rows carry the columns ride_points expects', () {
      final ride =
          reconciler.reconcile(_journey(speedMs: 11.1, seconds: 300)).ride!;
      final first = ride.points.first;

      for (final column in [
        'timestamp',
        'lat',
        'lng',
        'speed_ms',
        'acceleration',
        'jerk',
        'altitude_m',
        'period_type',
        'accuracy_m',
        'heading_deg',
        'confidence',
        'imu_quality',
        'is_cornering',
      ]) {
        expect(first.containsKey(column), isTrue, reason: 'missing $column');
      }
      // ride_id is stamped by the caller, not the reconciler.
      expect(first.containsKey('ride_id'), isFalse);
    });
  });

  group('replay honesty', () {
    test('a replayed journey does not manufacture a crash', () {
      // The regression this guards: EventDetector used to read DateTime.now()
      // internally. Replaying an hour of fixes takes milliseconds, so every
      // sample landed inside the same 2-second crash window and an ordinary
      // ride could trip the detector. With `at:` threaded through, the windows
      // are measured against the fixes' own timestamps.
      final outcome = reconciler.reconcile(
        _journey(speedMs: 11.1, seconds: 900),
      );
      expect(outcome.ride!.crashSuspected, isFalse);
    });

    test('EventDetector honours the injected clock', () {
      final detector = EventDetector();
      final t0 = DateTime(2026, 8, 16, 9);

      // A high-acceleration spike, then a stop — but ten seconds later, well
      // outside the two-second crash window. Real riding, not a crash.
      detector.detect(accel: 90.0, jerk: 12.0, speedMs: 15.0, at: t0);
      final late = detector.detect(
        accel: -85.0,
        jerk: -12.0,
        speedMs: 0.0,
        at: t0.add(const Duration(seconds: 10)),
      );

      expect(late, isNot(RideAlert.crash));
    });

    test('an injected clock still detects a genuine crash', () {
      final detector = EventDetector();
      final t0 = DateTime(2026, 8, 16, 9);

      // Same signal, compressed into the real window: spike and speed drop
      // within two seconds. This must still fire, or the clock injection would
      // have quietly disabled crash detection instead of correcting it.
      detector.detect(accel: 90.0, jerk: 12.0, speedMs: 15.0, at: t0);
      final alert = detector.detect(
        accel: -85.0,
        jerk: -12.0,
        speedMs: 0.5,
        at: t0.add(const Duration(milliseconds: 900)),
      );

      expect(alert, RideAlert.crash);
    });
  });
}
