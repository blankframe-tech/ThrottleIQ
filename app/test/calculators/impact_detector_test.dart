import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';

/// §78.1: ImpactDetector — raw-IMU spike, confirmed by a GPS stop plus
/// post-impact stillness or an orientation change.
void main() {
  const period = Duration(milliseconds: 50);
  final t0 = DateTime(2026, 9, 20, 9);

  late ImpactDetector detector;
  late List<CrashSignal> crashes;

  setUp(() {
    detector = ImpactDetector();
    crashes = [];
  });

  /// Feeds [duration] of 50 ms samples along the x axis, magnitude from
  /// [mag], starting at [from]. Returns the time after the last sample.
  DateTime feed(DateTime from, Duration duration, double Function(int i) mag) {
    var t = from;
    var i = 0;
    while (t.isBefore(from.add(duration))) {
      final s = detector.addSample(t, mag(i), 0, 0);
      if (s != null) crashes.add(s);
      t = t.add(period);
      i++;
    }
    return t;
  }

  void speed(DateTime t, double speedMs) {
    final s = detector.addSpeed(t, speedMs);
    if (s != null) crashes.add(s);
  }

  /// Riding at [speedMs] for 3 s before [t0], one fix per second.
  void rideUpTo(double speedMs) {
    for (var s = 3; s >= 0; s--) {
      speed(t0.subtract(Duration(seconds: s)), speedMs);
    }
    feed(t0.subtract(const Duration(seconds: 3)), const Duration(seconds: 3),
        (i) => i.isEven ? 0.8 : 1.2);
  }

  test('spike, stop, then stillness confirms a crash', () {
    rideUpTo(15);
    // Impact, then 1 s of tumbling, then lying still.
    var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
    t = feed(t, const Duration(seconds: 1), (i) => i.isEven ? 12 : 3);
    speed(t0.add(const Duration(seconds: 2)), 0.4);
    feed(t, const Duration(seconds: 5), (i) => i.isEven ? 0.05 : 0.1);

    expect(crashes, hasLength(1));
    expect(crashes.single.peakAccelerationMs2, 60);
    expect(crashes.single.hadSpeedDrop, isTrue);
    expect(detector.candidates.single.confirmed, isTrue);
    expect(detector.candidates.single.speedBeforeMs, 15);
  });

  test('pothole: 1-2 samples at 4-6 g while speed stays high does not fire',
      () {
    rideUpTo(12);
    var t = feed(t0, const Duration(milliseconds: 100), (i) => i == 0 ? 45 : 58);
    // Riding on, normal vibration, fixes still well above 8 m/s.
    for (var s = 1; s <= 10; s++) {
      speed(t0.add(Duration(seconds: s)), 12 - s * 0.2);
    }
    feed(t, const Duration(seconds: 10), (i) => i.isEven ? 0.8 : 1.4);

    expect(crashes, isEmpty);
    expect(detector.candidates, hasLength(1));
    expect(detector.candidates.single.confirmed, isFalse);
    expect(detector.candidates.single.peakAccelMs2, 58,
        reason: 'the peak is the max of the spike, never an average');
  });

  test('phone knocked off an already-parked bike does not fire', () {
    rideUpTo(0);
    var t = feed(t0, const Duration(milliseconds: 100), (_) => 70);
    speed(t0.add(const Duration(seconds: 1)), 0);
    feed(t, const Duration(seconds: 8), (_) => 0.05);

    expect(crashes, isEmpty);
  });

  test('stop without stillness or rotation does not fire', () {
    rideUpTo(15);
    var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
    speed(t0.add(const Duration(seconds: 2)), 0.3);
    // Rider picks the phone up and keeps handling it.
    feed(t, const Duration(seconds: 9), (i) => i.isEven ? 4 : 0.5);

    expect(crashes, isEmpty);
  });

  test('a stop seen after the confirm window does not count', () {
    rideUpTo(15);
    var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
    speed(t0.add(const Duration(seconds: 2)), 14);
    speed(t0.add(const Duration(seconds: 6)), 0.3);
    feed(t, const Duration(seconds: 9), (_) => 0.05);

    expect(crashes, isEmpty);
  });

  test('GPS silence after the spike counts as stopped only if still', () {
    rideUpTo(15);
    var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
    // No fixes at all afterwards (distance filter on a stopped bike).
    feed(t, const Duration(seconds: 7), (_) => 0.05);

    expect(crashes, hasLength(1));
  });

  test('orientation change confirms without stillness (engine running)', () {
    // Upright phone, gravity along +y.
    for (var i = 0; i < 40; i++) {
      detector.addGravitySample(
          t0.subtract(Duration(milliseconds: 2000 - i * 50)), 0, 9.8, 0);
    }
    rideUpTo(15);
    var t = feed(t0, const Duration(milliseconds: 100), (_) => 60);
    speed(t0.add(const Duration(seconds: 2)), 0.2);
    // Bike on its side: gravity now along +x, idle vibration continues.
    for (var i = 0; i < 60; i++) {
      detector.addGravitySample(t.add(period * i), 9.8, 0, 0);
    }
    feed(t, const Duration(seconds: 3), (i) => i.isEven ? 2.5 : 0.2);

    expect(crashes, hasLength(1));
    expect(detector.candidates.single.orientationChanged, isTrue);
  });

  test('a run of samples clipped at the ride max counts as a spike', () {
    // A 3 g sensor ceiling: below impactThreshold, but pinned.
    expect(29.0, lessThan(SensorConstants.impactThreshold));
    rideUpTo(15);
    var t = feed(t0, const Duration(milliseconds: 150), (_) => 29.0);
    expect(detector.hasPendingSpike, isTrue);
    speed(t0.add(const Duration(seconds: 1)), 0.5);
    feed(t, const Duration(seconds: 5), (_) => 0.05);

    expect(crashes, hasLength(1));
  });

  test('a phone at rest is not "saturated" at its own tiny max', () {
    feed(t0, const Duration(seconds: 2), (_) => 0.05);
    expect(detector.hasPendingSpike, isFalse);
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
}
