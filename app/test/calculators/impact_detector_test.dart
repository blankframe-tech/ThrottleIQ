import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';

/// ImpactDetector — three tiers (§78.1, crash-detection plan §3-4):
/// 0 = an impact (logged), 1 = a possible fall (asked after the ride),
/// 2 = a likely crash (the only tier that may alarm, returned as a
/// [CrashSignal]).
void main() {
  const period = Duration(milliseconds: 50);
  final t0 = DateTime(2026, 9, 20, 9);
  const g = 9.8;

  late ImpactDetector detector;
  late List<CrashSignal> crashes;
  late List<ImpactCandidate> resolved;

  setUp(() {
    resolved = [];
    detector = ImpactDetector(onCandidate: resolved.add);
    crashes = [];
  });

  void keep(CrashSignal? s) {
    if (s != null) crashes.add(s);
  }

  /// Feeds [duration] of 50 ms motion-filtered samples along x, magnitude
  /// from [mag], starting at [from]. With [gravity], also feeds an
  /// accelerometer sample including gravity at each tick, so the two streams
  /// stay in time order. Returns the time after the last sample.
  DateTime feed(DateTime from, Duration duration, double Function(int i) mag,
      {List<double>? gravity}) {
    var t = from;
    var i = 0;
    while (t.isBefore(from.add(duration))) {
      keep(detector.addSample(t, mag(i), 0, 0));
      if (gravity != null) {
        keep(detector.addGravitySample(t, gravity[0], gravity[1], gravity[2]));
      }
      t = t.add(period);
      i++;
    }
    return t;
  }

  void speed(DateTime t, double speedMs) => keep(detector.addSpeed(t, speedMs));

  double still(int i) => i.isEven ? 0.05 : 0.1;
  double handled(int i) => i.isEven ? 4 : 0.5; // rider moving the phone

  /// Riding at [speedMs] for 3 s before [t0], one fix per second.
  void rideUpTo(double speedMs, {List<double>? gravity}) {
    for (var s = 3; s >= 0; s--) {
      speed(t0.subtract(Duration(seconds: s)), speedMs);
    }
    feed(t0.subtract(const Duration(seconds: 3)), const Duration(seconds: 3),
        (i) => i.isEven ? 0.8 : 1.2,
        gravity: gravity);
  }

  group('tier 2: likely crash (may alarm)', () {
    test('spike, stop, then 10 s of stillness confirms a crash', () {
      rideUpTo(15);
      // Impact, then 1 s of tumbling, then lying still.
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      t = feed(t, const Duration(seconds: 1), (i) => i.isEven ? 12 : 3);
      speed(t0.add(const Duration(seconds: 2)), 0.4);
      feed(t, const Duration(seconds: 11), still);

      expect(crashes, hasLength(1));
      expect(crashes.single.peakAccelerationMs2, 60);
      expect(crashes.single.hadSpeedDrop, isTrue);
      final c = detector.candidates.single;
      expect(c.tier, 2);
      expect(c.confirmed, isTrue);
      expect(c.reason, ImpactReason.speedDrop);
      expect(c.speedBeforeMs, 15);
      expect(resolved, hasLength(1), reason: 'resolved exactly once');
    });

    test('pothole: 1-2 samples at 4-6 g while speed stays high is tier 0', () {
      rideUpTo(12);
      var t =
          feed(t0, const Duration(milliseconds: 100), (i) => i == 0 ? 45 : 58);
      // Riding on, normal vibration, fixes still well above 8 m/s.
      for (var s = 1; s <= 27; s++) {
        speed(t0.add(Duration(seconds: s)), 12 - s * 0.1);
        t = feed(t, const Duration(seconds: 1), (i) => i.isEven ? 0.8 : 1.4);
      }

      expect(crashes, isEmpty);
      final c = detector.candidates.single;
      expect(c.tier, 0);
      expect(c.resumed, isTrue);
      expect(c.peakAccelMs2, 58,
          reason: 'the peak is the max of the spike, never an average');
    });

    test('phone knocked off an already-parked bike never alarms', () {
      rideUpTo(0);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 70);
      speed(t0.add(const Duration(seconds: 1)), 0);
      feed(t, const Duration(seconds: 27), (_) => 0.05);

      expect(crashes, isEmpty);
      expect(detector.candidates.single.tier, 0,
          reason: 'no speed drop, and no rotation for the tip-over rule');
    });

    test('stop without stillness or rotation never alarms', () {
      rideUpTo(15);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      speed(t0.add(const Duration(seconds: 2)), 0.3);
      // Rider picks the phone up and keeps handling it.
      feed(t, const Duration(seconds: 27), handled);

      expect(crashes, isEmpty);
      // But the bike never rode on, so it's still worth asking about.
      expect(detector.candidates.single.tier, 1);
      expect(detector.candidates.single.wentStill, isFalse);
    });

    test('a bike that rode on after the impact is not a fall', () {
      rideUpTo(15);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      speed(t0.add(const Duration(seconds: 2)), 14);
      speed(t0.add(const Duration(seconds: 6)), 0.3);
      feed(t, const Duration(seconds: 27), still);

      expect(crashes, isEmpty);
      expect(detector.candidates.single.tier, 0);
      expect(detector.candidates.single.resumed, isTrue);
    });

    test('GPS silence counts as stopped; 10 s of stillness then alarms', () {
      rideUpTo(15);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      // No fixes at all afterwards (distance filter on a stopped bike).
      feed(t, const Duration(seconds: 12), still);

      expect(crashes, hasLength(1));
    });

    test('orientation held 5 s confirms without stillness (engine running)',
        () {
      // Upright phone, gravity along +y.
      rideUpTo(15, gravity: const [0, g, 0]);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      speed(t0.add(const Duration(seconds: 2)), 0.2);
      // Bike on its side: gravity now along +x, idle vibration continues.
      feed(t, const Duration(seconds: 7), (i) => i.isEven ? 2.5 : 0.2,
          gravity: const [g, 0, 0]);

      expect(crashes, hasLength(1));
      expect(detector.candidates.single.orientationChanged, isTrue);
      expect(detector.candidates.single.wentStill, isFalse);
    });

    test('a run of samples clipped at the ride max counts as a hard impact',
        () {
      // A 2.2 g sensor ceiling: below even the ask threshold, but pinned.
      expect(22.0, lessThan(SensorConstants.impactAskThreshold));
      rideUpTo(15);
      var t = feed(t0, const Duration(milliseconds: 150), (_) => 22.0);
      expect(detector.hasPendingSpike, isTrue);
      speed(t0.add(const Duration(seconds: 1)), 0.5);
      feed(t, const Duration(seconds: 12), still);

      expect(crashes, hasLength(1));
      expect(detector.candidates.single.saturated, isTrue);
    });

    test('under 15 km/h before the impact it asks, never alarms', () {
      rideUpTo(3.5);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      speed(t0.add(const Duration(seconds: 2)), 0.2);
      feed(t, const Duration(seconds: 27), still);

      expect(crashes, isEmpty);
      expect(detector.candidates.single.tier, 1);
    });

    test('a 3 g knock is below the alarm bar but above the ask bar', () {
      rideUpTo(15);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 29);
      speed(t0.add(const Duration(seconds: 2)), 0.2);
      feed(t, const Duration(seconds: 27), still);

      expect(crashes, isEmpty);
      expect(detector.candidates.single.tier, 1);
      expect(detector.candidates.single.peakG, closeTo(29 / 9.81, 0.01));
    });
  });

  group('tier 1: possible fall (asked after the ride)', () {
    test('speed before is found up to 10 s back (sparse fixes at walking pace)',
        () {
      speed(t0.subtract(const Duration(seconds: 8)), 3.5);
      feed(t0.subtract(const Duration(seconds: 8)), const Duration(seconds: 8),
          (i) => i.isEven ? 0.8 : 1.2);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      feed(t, const Duration(seconds: 27), still);

      final c = detector.candidates.single;
      expect(c.tier, 1);
      expect(c.speedBeforeMs, 3.5);
      expect(c.speedAfterMs, isNull, reason: 'GPS was silent the whole time');
      expect(c.lastFixAgeS, closeTo(8, 0.01));
    });

    test('a walking-pace fall (1.5 m/s to 0.2) still counts', () {
      rideUpTo(1.5);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      speed(t0.add(const Duration(seconds: 2)), 0.2);
      feed(t, const Duration(seconds: 27), still);

      expect(detector.candidates.single.tier, 1);
    });

    test('a stop seen through silence stays seen after a late slow fix', () {
      rideUpTo(3.5);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      t = feed(t, const Duration(seconds: 12), handled);
      speed(t, 0.0); // 12 s after: outside the stop window, but latched
      feed(t, const Duration(seconds: 15), handled);

      final c = detector.candidates.single;
      expect(c.tier, 1, reason: 'stopped (latched) + didn\'t ride on');
      expect(c.wentStill, isFalse);
    });

    test('a fast fix right after the impact is stale GPS, not a ride-on', () {
      rideUpTo(15);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
      speed(t0.add(const Duration(milliseconds: 500)), 8);
      speed(t0.add(const Duration(seconds: 3)), 0.2);
      feed(t, const Duration(seconds: 12), still);

      expect(crashes, hasLength(1));
      expect(detector.candidates.single.resumed, isFalse);
    });

    test('tip-over from a standstill: impact, then the phone stays turned', () {
      rideUpTo(0, gravity: const [0, 0, g]);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      feed(t, const Duration(seconds: 27), still, gravity: const [g, 0, 0]);

      expect(crashes, isEmpty, reason: 'tip-overs only ever ask');
      final c = detector.candidates.single;
      expect(c.tier, 1);
      expect(c.reason, ImpactReason.tipOver);
      expect(c.orientationChangeDeg, greaterThan(80));
    });

    test('a tip-over needs the rotation to hold for 5 s', () {
      rideUpTo(0, gravity: const [0, 0, g]);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      t = feed(t, const Duration(seconds: 2), still, gravity: const [g, 0, 0]);
      feed(t, const Duration(seconds: 25), still, gravity: const [0, 0, g]);

      expect(detector.candidates.single.tier, 0,
          reason: 'turned back within 2 s: picked up, not lying down');
    });

    test('no fix for 3 s before the impact also means stopped', () {
      // The 14 Oct 2026 tip-over reading: last fix 12 s earlier at 3.5 m/s.
      speed(t0.subtract(const Duration(seconds: 12)), 3.5);
      feed(t0.subtract(const Duration(seconds: 3)), const Duration(seconds: 3),
          still,
          gravity: const [0, g, 0]);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 28);
      feed(t, const Duration(seconds: 27), still, gravity: const [0, 0, g]);

      final c = detector.candidates.single;
      expect(c.tier, 1);
      expect(c.reason, ImpactReason.tipOver);
      expect(c.speedBeforeMs, 0, reason: 'the fix was outside the 10 s window');
    });
  });

  group('impacts (tier 0)', () {
    test('a free fall ending opens an impact and records how long it fell', () {
      var t = t0;
      for (var i = 0; i < 20; i++, t = t.add(period)) {
        detector.addGravitySample(t, 0, 0, g);
      }
      for (var i = 0; i < 4; i++, t = t.add(period)) {
        detector.addGravitySample(t, 0, 0, 0.5); // 200 ms falling
      }
      detector.addGravitySample(t, 0, 0, g); // landed
      expect(detector.hasPendingSpike, isTrue);
      for (var i = 0; i < 27 * 20; i++) {
        t = t.add(period);
        detector.addGravitySample(t, 0, 0, g);
      }

      expect(detector.candidates.single.freefallMs, 200);
    });

    test('the raw stream alone can open an impact', () {
      detector.addGravitySample(t0, 0, 0, g);
      detector.addGravitySample(t0.add(period), 0, 0, g + 30);
      expect(detector.hasPendingSpike, isTrue);
      var t = t0.add(period);
      for (var i = 0; i < 27 * 20; i++) {
        t = t.add(period);
        detector.addGravitySample(t, 0, 0, g);
      }
      // The detector subtracts 9.81; this test's gravity is 9.8.
      expect(
          detector.candidates.single.peakRawMs2, closeTo(30 + g - 9.81, 1e-9));
    });

    test('gyro rotation in the 2 s after the impact is measured', () {
      final t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      var gt = t;
      for (var i = 0; i < 20; i++, gt = gt.add(period)) {
        detector.addGyroSample(gt, 3, 0, 0); // 3 rad/s for 1 s
      }
      feed(t, const Duration(seconds: 27), still);
      // 19 integrated gaps of 50 ms at 3 rad/s.
      expect(detector.candidates.single.rotationDeg, closeTo(163.3, 0.5));
    });

    test('vibration before the impact is recorded, the impact itself is not',
        () {
      feed(t0.subtract(const Duration(seconds: 10)),
          const Duration(seconds: 10), (i) => i.isEven ? 1.0 : 3.0);
      final t = feed(t0, const Duration(milliseconds: 50), (_) => 60);
      feed(t, const Duration(seconds: 27), still);
      expect(detector.candidates.single.vibrationRmsMs2, closeTo(2.236, 0.01));
    });

    test('a phone at rest is not "saturated" at its own tiny max', () {
      feed(t0, const Duration(seconds: 2), (_) => 0.05);
      expect(detector.hasPendingSpike, isFalse);
    });

    test('features carry every measurement, rounded', () {
      rideUpTo(3.5);
      final t = feed(t0, const Duration(milliseconds: 100), (_) => 30.123456);
      feed(t, const Duration(seconds: 27), still);
      final f = detector.candidates.single.toFeatures();
      expect(f['peakUserMs2'], 30.12);
      expect(
          f.keys,
          containsAll([
            'freefallMs',
            'rotationDeg',
            'wentStill',
            'resumed',
            'saturated',
            'lastFixAgeS',
            'vibrationRmsMs2'
          ]));
    });

    test('flush resolves a pending impact at the tier it reached', () {
      rideUpTo(3.5);
      var t = feed(t0, const Duration(milliseconds: 100), (_) => 30);
      feed(t, const Duration(seconds: 6), still); // tier 1 by now, still open
      expect(detector.hasPendingSpike, isTrue);
      detector.flush();
      expect(detector.hasPendingSpike, isFalse);
      expect(resolved.single.tier, 1);
      detector.flush(); // nothing pending: no second candidate
      expect(resolved, hasLength(1));
    });

    test('reset clears pending state and history', () {
      rideUpTo(15);
      feed(t0, const Duration(milliseconds: 100), (_) => 60);
      expect(detector.hasPendingSpike, isTrue);
      detector.reset();
      expect(detector.hasPendingSpike, isFalse);
      expect(detector.candidates, isEmpty);
      expect(detector.lastCrashSignal, isNull);
    });
  });
}
