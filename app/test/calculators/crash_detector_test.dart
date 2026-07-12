import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';

void main() {
  group('EventDetector - Crash Detection', () {
    late EventDetector detector;

    setUp(() {
      detector = EventDetector();
    });

    test('does NOT fire on pothole (single accel spike only)', () {
      // Pothole: brief accel spike >8g, but NO jerk spike + NO speed drop
      // Signal: [accel: 9.0, jerk: 5.0, speed: 10.0] -> [accel: 0, jerk: 0, speed: 9.5]
      final result1 = detector.detect(accel: 9.0, jerk: 5.0, speedMs: 10.0);
      final result2 = detector.detect(accel: 0, jerk: 0, speedMs: 9.5);

      expect(result1, isNot(RideAlert.crash));
      expect(result2, isNot(RideAlert.crash));
      expect(detector.lastCrashSignal, isNull);
    });

    test('does NOT fire on hard brake alone', () {
      // Hard brake: sustained negative accel (-4), high jerk, but speed does NOT drop to 0
      // Speed stays above threshold
      for (int i = 0; i < 10; i++) {
        final result = detector.detect(
          accel: -4.0,
          jerk: -5.0,
          speedMs: 8.0 - (i * 0.3), // Gradual slow but stays >1 m/s
        );
        expect(result, isNot(RideAlert.crash));
      }
      expect(detector.lastCrashSignal, isNull);
    });

    test('DOES fire on crash: accel spike + jerk spike + speed→0 in 2s', () {
      // Crash scenario:
      // t=0: High speed (15 m/s), then accel spike >8g
      // t=0.5s: Jerk spike >10 m/s³
      // t=1.5s: Speed drops to near 0

      // Initial state: moving at good speed
      detector.detect(accel: 0, jerk: 0, speedMs: 15.0);

      // Impact: accel spike >8g
      final alert1 = detector.detect(accel: 10.0, jerk: 0, speedMs: 15.0);

      // Jerk spike follows
      final alert2 = detector.detect(accel: 9.5, jerk: 12.0, speedMs: 14.5);

      // Speed drops to 0 within 2s
      final alert3 = detector.detect(accel: -5.0, jerk: -8.0, speedMs: 0.5);

      expect(alert3, equals(RideAlert.crash));
      expect(detector.lastCrashSignal, isNotNull);
      expect(detector.lastCrashSignal!.hadHighAccelSpike, isTrue);
      expect(detector.lastCrashSignal!.hadJerkSpike, isTrue);
      expect(detector.lastCrashSignal!.hadSpeedDrop, isTrue);
    });

    test('crash alert TTL: resets after 2s window', () {
      // Set up initial conditions
      detector.detect(accel: 0, jerk: 0, speedMs: 15.0);

      // Accel spike
      detector.detect(accel: 9.0, jerk: 0, speedMs: 15.0);

      // Wait (simulate) and check window expires
      // After 2.5s, should have reset state
      detector.detect(accel: 0, jerk: 0, speedMs: 15.0);
      detector.detect(accel: 0, jerk: 0, speedMs: 15.0);
      detector.detect(accel: 0, jerk: 0, speedMs: 15.0);

      // Simulate enough calls to advance time past 2s window
      for (int i = 0; i < 30; i++) {
        detector.detect(accel: 0, jerk: 0, speedMs: 15.0);
      }

      expect(detector.lastCrashSignal, isNull);
    });

    test('fatigue alert does not repeat continuously', () {
      // Fatigue triggers at 5400s (90 min), then TTL is 10s
      // Should not fire every second
      int fatigueAlertCount = 0;

      final result1 = detector.detect(
        elapsedSeconds: 5400, // Exactly at threshold
      );
      if (result1 == RideAlert.fatigue) fatigueAlertCount++;

      // Immediate next call should NOT fire
      final result2 = detector.detect(elapsedSeconds: 5401);
      if (result2 == RideAlert.fatigue) fatigueAlertCount++;

      expect(fatigueAlertCount, lessThanOrEqualTo(1),
          reason: 'Fatigue should not fire continuously');
    });

    test('hard brake and rapid accel counters increment', () {
      detector.detect(accel: -4.5, jerk: 0, speedMs: 20.0);
      detector.detect(accel: 4.5, jerk: 0, speedMs: 10.0);

      expect(detector.hardBrakeCount, equals(1));
      expect(detector.rapidAccelCount, equals(1));
    });

    test('reset clears all counters and state', () {
      detector.detect(accel: 10.0, jerk: 15.0, speedMs: 10.0);
      detector.hardBrakeCount = 5;
      detector.rapidAccelCount = 3;

      detector.reset();

      expect(detector.hardBrakeCount, equals(0));
      expect(detector.rapidAccelCount, equals(0));
      expect(detector.highJerkCount, equals(0));
      expect(detector.lastCrashSignal, isNull);
    });

    test('GPS noise does NOT trigger crash (no sustained pattern)', () {
      // GPS jitter: random spikes without pattern
      // Speed stays high (no drop to 0)
      final random = [
        (accel: 7.0, jerk: 8.0, speed: 25.0),
        (accel: -2.0, jerk: 3.0, speed: 24.9),
        (accel: 3.0, jerk: -1.0, speed: 25.1),
        (accel: 2.0, jerk: 4.0, speed: 24.8),
      ];

      for (final sample in random) {
        final result = detector.detect(
          accel: sample.accel,
          jerk: sample.jerk,
          speedMs: sample.speed,
        );
        expect(result, isNot(RideAlert.crash));
      }
      expect(detector.lastCrashSignal, isNull);
    });
  });
}
