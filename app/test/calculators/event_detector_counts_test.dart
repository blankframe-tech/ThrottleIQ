import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';

void main() {
  final t0 = DateTime(2026, 9, 20, 9);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('jerk peak in the crash window (§78.2)', () {
    CrashSignal crashWithJerks(List<double> jerks) {
      final detector = EventDetector();
      detector.detect(accel: 0, jerk: 0, speedMs: 15, at: at(0));
      var ms = 100;
      for (var i = 0; i < jerks.length; i++) {
        detector.detect(
            accel: i == 0 ? 90 : 0, jerk: jerks[i], speedMs: 14, at: at(ms));
        ms += 100;
      }
      final alert =
          detector.detect(accel: 0, jerk: 0, speedMs: 0.5, at: at(ms));
      expect(alert, RideAlert.crash);
      return detector.lastCrashSignal!;
    }

    test('[14, 5.5] keeps the peak at 14', () {
      expect(crashWithJerks([14, 5.5]).peakJerkMs3, 14);
    });

    test('[14, 11] keeps the peak at 14, not the 12.5 average', () {
      expect(crashWithJerks([14, 11]).peakJerkMs3, 14);
    });

    test('a later, larger jerk raises the peak', () {
      expect(crashWithJerks([11, 14]).peakJerkMs3, 14);
    });
  });

  group('GPS-path longitudinal counts (§78.3)', () {
    test('a brake spanning several fixes counts once', () {
      final d = EventDetector();
      for (var i = 0; i < 5; i++) {
        d.detect(accel: -5, speedMs: 10, at: at(i * 500));
      }
      expect(d.hardBrakeCount, 1);
    });

    test('re-arms after recovering past -2 m/s²', () {
      final d = EventDetector();
      d.detect(accel: -5, speedMs: 10, at: at(0));
      d.detect(accel: -3, speedMs: 9, at: at(500));
      d.detect(accel: -5, speedMs: 8, at: at(1000));
      expect(d.hardBrakeCount, 1);
      d.detect(accel: -1, speedMs: 8, at: at(1500));
      d.detect(accel: -5, speedMs: 6, at: at(2000));
      expect(d.hardBrakeCount, 2);
    });

    test('rapid accel has the same shape', () {
      final d = EventDetector();
      d.detect(accel: 5, speedMs: 5, at: at(0));
      d.detect(accel: 5, speedMs: 7, at: at(500));
      d.detect(accel: 1, speedMs: 8, at: at(1000));
      d.detect(accel: 5, speedMs: 10, at: at(1500));
      expect(d.rapidAccelCount, 2);
    });

    test('countLongitudinal: false leaves the counts to the IMU', () {
      final d = EventDetector();
      final alert = d.detect(
          accel: -5, speedMs: 10, at: at(0), countLongitudinal: false);
      d.detect(accel: 5, speedMs: 10, at: at(500), countLongitudinal: false);
      expect(alert, RideAlert.none);
      expect(d.hardBrakeCount, 0);
      expect(d.rapidAccelCount, 0);
    });
  });

  test('detectCrash: false takes the GPS crash branch off the live path', () {
    final d = EventDetector();
    d.detect(accel: 90, jerk: 12, speedMs: 15, at: at(0), detectCrash: false);
    final alert = d.detect(
        accel: -85, jerk: -12, speedMs: 0.5, at: at(900), detectCrash: false);
    expect(alert, isNot(RideAlert.crash));
    expect(d.lastCrashSignal, isNull);
  });
}
