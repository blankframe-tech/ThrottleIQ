import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';

/// Covers the alert-shaping behaviour added in issues §83.5-81.8. The crash
/// pipeline itself is covered by `crash_detector_test.dart`.
void main() {
  late EventDetector detector;
  late DateTime t0;

  setUp(() {
    detector = EventDetector();
    t0 = DateTime(2026, 9, 21, 9);
  });

  group('overspeed hysteresis (§83.7)', () {
    test('fires once per excursion, not once per fix above the limit', () {
      var fired = 0;
      // Ten consecutive fixes, all well over the 27.8 m/s default.
      for (var i = 0; i < 10; i++) {
        final alert = detector.detect(
          speedMs: 30.0,
          at: t0.add(Duration(seconds: i)),
        );
        if (alert == RideAlert.overspeed) fired++;
      }
      expect(fired, 1,
          reason: 'sustained speeding is one excursion, not ten alerts');
    });

    test('re-arms only after dropping clear of the limit', () {
      expect(detector.detect(speedMs: 30.0, at: t0), RideAlert.overspeed);

      // Hovering just under the threshold is inside the re-arm band, so
      // going back over must NOT alert again — this is the case that used to
      // strobe the cockpit.
      expect(
        detector.detect(speedMs: 27.5, at: t0.add(const Duration(seconds: 1))),
        isNot(RideAlert.overspeed),
      );
      expect(
        detector.detect(speedMs: 30.0, at: t0.add(const Duration(seconds: 2))),
        isNot(RideAlert.overspeed),
      );

      // Genuinely slowing down re-arms it.
      expect(
        detector.detect(speedMs: 20.0, at: t0.add(const Duration(seconds: 3))),
        isNot(RideAlert.overspeed),
      );
      expect(
        detector.detect(speedMs: 30.0, at: t0.add(const Duration(seconds: 4))),
        RideAlert.overspeed,
      );
    });

    test('reset() re-arms', () {
      expect(detector.detect(speedMs: 30.0, at: t0), RideAlert.overspeed);
      detector.reset();
      expect(
        detector.detect(speedMs: 30.0, at: t0.add(const Duration(seconds: 1))),
        RideAlert.overspeed,
      );
    });
  });

  group('fatigue reminder (§83.8)', () {
    const past = SensorConstants.fatigueAlertSeconds;

    test('does not become a permanent alert state after 90 minutes', () {
      var fired = 0;
      // Five minutes of once-a-second ticks, all past the fatigue threshold.
      for (var i = 0; i < 300; i++) {
        final alert = detector.detect(
          elapsedSeconds: past + i,
          at: t0.add(Duration(seconds: i)),
        );
        if (alert == RideAlert.fatigue) fired++;
      }
      expect(fired, 1,
          reason: 'it used to re-fire every 10s forever, with no dismiss');
    });

    test('repeats once the reminder interval has elapsed', () {
      expect(detector.detect(elapsedSeconds: past, at: t0), RideAlert.fatigue);

      final justBefore = t0
          .add(EventDetector.fatigueRepeatInterval)
          .subtract(const Duration(seconds: 1));
      expect(
        detector.detect(elapsedSeconds: past + 1, at: justBefore),
        isNot(RideAlert.fatigue),
      );

      final after = t0.add(EventDetector.fatigueRepeatInterval);
      expect(
        detector.detect(elapsedSeconds: past + 2, at: after),
        RideAlert.fatigue,
      );
    });
  });

  group('speed history is not crash state (§83.5)', () {
    test('an expired accel window does not blind the speed-drop check', () {
      // A pothole opens — and then expires — an accel-spike window.
      detector.detect(accel: 100.0, speedMs: 20.0, at: t0);
      detector.detect(
          accel: 0, speedMs: 20.0, at: t0.add(const Duration(seconds: 3)));

      // Immediately afterwards, a real impact. The 2 s speed history must
      // still be there for the speed-drop leg to evaluate; it used to be
      // cleared along with the window.
      detector.detect(
          accel: 0,
          speedMs: 20.0,
          at: t0.add(const Duration(seconds: 3, milliseconds: 100)));
      final alert = detector.detect(
        accel: 100.0,
        jerk: 15.0,
        speedMs: 0.2,
        at: t0.add(const Duration(seconds: 4)),
      );

      expect(alert, RideAlert.crash);
      expect(detector.lastCrashSignal!.hadSpeedDrop, isTrue);
    });
  });

  group('speed collapse while still moving (§83.6)', () {
    test('a slide that keeps some speed still counts as a crash', () {
      detector.detect(accel: 0, speedMs: 24.0, at: t0);
      // Impact: accel + jerk spike, speed collapses 24 -> 6 m/s but the bike
      // is still sliding, so the old `< 1.0 m/s` rule saw no speed drop.
      final alert = detector.detect(
        accel: 100.0,
        jerk: 15.0,
        speedMs: 6.0,
        at: t0.add(const Duration(seconds: 1)),
      );
      expect(alert, RideAlert.crash);
      expect(detector.lastCrashSignal!.hadSpeedDrop, isTrue);
    });

    test('ordinary braking does not count as a collapse', () {
      detector.detect(accel: 0, speedMs: 20.0, at: t0);
      // Firm braking sheds 6 m/s — under half the entry speed — and there is
      // no 8 g accel spike, so nothing should fire as a crash.
      final alert = detector.detect(
        accel: -4.5,
        jerk: 15.0,
        speedMs: 14.0,
        at: t0.add(const Duration(seconds: 1)),
      );
      expect(alert, isNot(RideAlert.crash));
      expect(detector.lastCrashSignal, isNull);
    });
  });
}
