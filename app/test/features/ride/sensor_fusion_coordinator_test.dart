import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:throttleiq/features/ride/domain/calculators/accel_axis_calibrator.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_window_recorder.dart';
import 'package:throttleiq/features/ride/presentation/providers/helpers/sensor_fusion_coordinator.dart';

/// An axis already fitted to device x — skips the GPS pairing the real
/// calibrator needs before it will project.
class _CalibratedOnX extends AccelAxisCalibrator {
  @override
  bool get isCalibrated => true;

  @override
  double signedLongitudinalAccelMs2(double ax, double ay, double az) => ax;
}

void main() {
  const period = Duration(milliseconds: 50);
  final t0 = DateTime(2026, 9, 20, 9);

  late EventDetector detector;
  late List<RideAlert> alerts;
  late List<CrashSignal> crashes;
  late List<(ImpactCandidate, Uint8List?)> saved;

  setUp(() {
    detector = EventDetector();
    alerts = [];
    crashes = [];
    saved = [];
  });

  SensorFusionCoordinator coordinator({
    bool calibrated = true,
    bool impact = false,
    bool alarms = false,
  }) =>
      SensorFusionCoordinator(
        axisCalibrator: calibrated ? _CalibratedOnX() : AccelAxisCalibrator(),
        impactDetectionEnabled: impact,
        crashAlertsEnabled: alarms,
        onImpactCrash: crashes.add,
        onImpactCandidate: (c, w) => saved.add((c, w)),
        alertHaptic: () async {},
        random: math.Random(3),
      );

  /// Feeds [count] samples of (x, y, z) 50 ms apart from [from]; returns the
  /// time after the last one.
  DateTime feed(SensorFusionCoordinator c, DateTime from, int count, double x,
      [double y = 0, double z = 0]) {
    var t = from;
    for (var i = 0; i < count; i++) {
      c.onAccelEvent(
        event: UserAccelerometerEvent(x, y, z),
        detector: detector,
        onUiPush: (_) {},
        onAlertTriggered: alerts.add,
        at: t,
      );
      t = t.add(period);
    }
    return t;
  }

  group('brake/accel counting (§78.3, §78.13)', () {
    test('60 samples held at -5 m/s² count one hard brake', () {
      final c = coordinator();
      feed(c, t0, 60, -5);
      expect(detector.hardBrakeCount, 1);
      expect(alerts, [RideAlert.hardBraking]);
    });

    test('re-arms only after rising past -2 m/s², and respects cooldown', () {
      final c = coordinator();
      var t = feed(c, t0, 60, -5); // brake 1, 3 s
      t = feed(c, t, 40, 0); // release, filtered accel back near 0
      feed(c, t, 60, -5); // brake 2
      expect(detector.hardBrakeCount, 2);
    });

    test('a dip that never recovers past the re-arm level is one event', () {
      final c = coordinator();
      var t = feed(c, t0, 60, -5);
      t = feed(c, t, 60, -3); // eases, but stays below -2
      feed(c, t, 60, -5);
      expect(detector.hardBrakeCount, 1);
    });

    test('rapid acceleration has the same shape', () {
      final c = coordinator();
      var t = feed(c, t0, 60, 5);
      expect(detector.rapidAccelCount, 1);
      t = feed(c, t, 40, 0);
      feed(c, t, 60, 5);
      expect(detector.rapidAccelCount, 2);
    });

    test('no IMU brake/accel events before the axis is calibrated', () {
      final c = coordinator(calibrated: false);
      var t = feed(c, t0, 60, -5); // pothole-like: a single dominant axis
      feed(c, t, 60, 0, 0, 6);
      expect(detector.hardBrakeCount, 0);
      expect(detector.rapidAccelCount, 0);
      expect(alerts, isEmpty);
    });
  });

  group('impact pipeline (§78.1)', () {
    /// Raw 50 ms samples + GPS speeds through the coordinator, as the ride
    /// recorder would feed them.
    void crashScenario(SensorFusionCoordinator c) {
      for (var s = 3; s >= 0; s--) {
        c.onGpsSpeed(t0.subtract(Duration(seconds: s)), 15);
      }
      var t = feed(c, t0.subtract(const Duration(seconds: 2)), 40, 1, 0.5);
      t = feed(c, t, 2, 45, 30, 10); // |a| ≈ 55 m/s² impact
      t = feed(c, t, 20, 8, -6, 3); // tumbling
      c.onGpsSpeed(t, 0.3);
      feed(c, t, 220, 0.05, 0.02, 0.03); // lying still, 11 s
    }

    test('raw samples + GPS stop fire a crash when alarms are on', () {
      final c = coordinator(impact: true, alarms: true);
      crashScenario(c);
      expect(crashes, hasLength(1));
      expect(crashes.single.peakAccelerationMs2, greaterThan(50));
    });

    test('the low-pass filter would have hidden the spike', () {
      final c = coordinator(impact: true, alarms: true);
      crashScenario(c);
      expect(c.filteredAccel.abs(), lessThan(10),
          reason: 'detection must run on raw samples, not the α=0.1 filter');
    });

    test('shadow mode saves the crash with its window but never alarms', () {
      final c = coordinator(impact: true);
      crashScenario(c);
      expect(crashes, isEmpty);
      final (candidate, window) = saved.single;
      expect(candidate.tier, 2);
      expect(window, isNotNull);
      final decoded = ImpactWindowRecorder.decode(window!);
      expect(decoded.user, isNotEmpty);
      expect(decoded.user.first.offsetMs, lessThan(0),
          reason: 'the window starts before the impact');
    });

    test('nothing runs while shadow mode is off', () {
      final c = coordinator(impact: false, alarms: true);
      crashScenario(c);
      expect(crashes, isEmpty);
      expect(c.impactDetector.candidates, isEmpty);
      expect(saved, isEmpty);
    });

    test('per-ride caps bound what a rough road can save', () {
      final c = coordinator(impact: true);
      var t = t0;
      // 30 separate knocks at speed, each followed by riding on.
      for (var k = 0; k < 30; k++) {
        c.onGpsSpeed(t, 12);
        t = feed(c, t, 2, 0, 0, 40);
        for (var s = 0; s < 27; s++) {
          c.onGpsSpeed(t, 12);
          t = feed(c, t, 20, 0.5, 0.3, 0.2);
        }
      }
      expect(saved, hasLength(SensorFusionCoordinator.maxCandidatesPerRide));
      expect(saved.where((s) => s.$2 != null).length,
          lessThanOrEqualTo(SensorFusionCoordinator.maxWindowsPerRide));
      expect(saved.every((s) => s.$1.tier == 0), isTrue);
    });

    test('a pause does not drag the measured IMU rate down', () {
      final c = coordinator(impact: true);
      var t = feed(c, t0, 21, 0.1); // 1 s at 20 Hz
      t = t.add(const Duration(minutes: 5)); // paused
      feed(c, t, 21, 0.1);
      expect(c.achievedImuRateHz, closeTo(20, 0.01));
    });

    test('a ride ending inside the window still saves the impact', () {
      final c = coordinator(impact: true);
      crashScenario(c);
      saved.clear();
      var t = t0.add(const Duration(minutes: 1));
      c.onGpsSpeed(t, 12);
      t = feed(c, t, 2, 0, 0, 40); // a knock 2 s before stopping
      feed(c, t, 40, 0.5, 0.3, 0.2);
      expect(saved, isEmpty);
      c.flushPendingImpact();
      expect(saved.single.$1.tier, 0);
    });

    test('reset starts the per-ride caps and the rate meter again', () {
      final c = coordinator(impact: true);
      feed(c, t0, 21, 0.1);
      expect(c.achievedImuRateHz, closeTo(20, 0.01));
      c.reset();
      expect(c.achievedImuRateHz, isNull);
    });

    test('pothole spikes at speed do not fire', () {
      final c = coordinator(impact: true, alarms: true);
      for (var s = 3; s >= 0; s--) {
        c.onGpsSpeed(t0.subtract(Duration(seconds: s)), 12);
      }
      var t = feed(c, t0, 1, 0, 0, 50);
      t = feed(c, t, 1, 0, 0, 40);
      for (var s = 1; s <= 10; s++) {
        c.onGpsSpeed(t0.add(Duration(seconds: s)), 11.5);
      }
      feed(c, t, 560, 1, 0.3, 0.8);
      expect(crashes, isEmpty);
      expect(c.impactDetector.candidates.single.confirmed, isFalse);
      expect(c.impactDetector.candidates.single.tier, 0);
    });
  });

  group('low-pass filter (50 Hz)', () {
    test('the time constant is the same at 20 ms as at 50 ms', () {
      final slow = coordinator(calibrated: false);
      final fast = SensorFusionCoordinator(
        axisCalibrator: AccelAxisCalibrator(),
        impactDetectionEnabled: false,
        alertHaptic: () async {},
      );
      // One second of a 3 m/s² step at each rate.
      feed(slow, t0, 20, 3);
      var t = t0;
      for (var i = 0; i < 50; i++) {
        fast.onAccelEvent(
          event: UserAccelerometerEvent(3, 0, 0),
          detector: detector,
          onUiPush: (_) {},
          onAlertTriggered: alerts.add,
          at: t,
        );
        t = t.add(const Duration(milliseconds: 20));
      }
      expect(fast.filteredAccel, closeTo(slow.filteredAccel, 0.15),
          reason: 'more samples per second must not make the filter faster');
    });
  });
}
