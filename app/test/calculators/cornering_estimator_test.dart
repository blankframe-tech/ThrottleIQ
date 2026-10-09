import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/cornering_estimator.dart';

/// GPS-kinematics lean / g estimator: a_lat = v·ω, lean = atan(a_lat / g).
void main() {
  final t0 = DateTime(2026, 10, 9, 8);

  /// Feeds [n] fixes, one per second, with heading/speed from callbacks.
  CorneringEstimator feed(
    int n, {
    required double Function(int i) speed,
    required double Function(int i) heading,
    CorneringEstimator? into,
    int startSecond = 0,
  }) {
    final e = into ?? CorneringEstimator();
    for (var i = 0; i < n; i++) {
      e.addFix(
        time: t0.add(Duration(seconds: startSecond + i)),
        speedMs: speed(i),
        headingDeg: heading(i) % 360,
      );
    }
    return e;
  }

  group('steady circle', () {
    // v = 15 m/s round a 50 m radius: ω = v/R = 0.3 rad/s,
    // a_lat = v²/R = 4.5 m/s², lean = atan(4.5 / g) ≈ 24.65°.
    const v = 15.0;
    const r = 50.0;
    const omegaDegS = v / r * 180 / math.pi;
    final expectedLean =
        math.atan(v * v / r / kStandardGravity) * 180 / math.pi;

    test('right-hand circle gives the expected lean and lateral g', () {
      final e = feed(20, speed: (_) => v, heading: (i) => 10 + omegaDegS * i);
      final p = e.peaks;
      expect(p.maxLeanDeg, closeTo(expectedLean, 0.3));
      expect(p.maxLeanRightDeg, closeTo(expectedLean, 0.3));
      expect(p.maxLeanLeftDeg, 0);
      expect(p.peakLateralG, closeTo(v * v / r / kStandardGravity, 0.01));
    });

    test('left-hand circle reads as a left lean, including across north', () {
      final e = feed(20, speed: (_) => v, heading: (i) => 30 - omegaDegS * i);
      final p = e.peaks;
      expect(p.maxLeanLeftDeg, closeTo(expectedLean, 0.3));
      expect(p.maxLeanRightDeg, 0);
      final last = e.addFix(
          time: t0.add(const Duration(seconds: 20)),
          speedMs: v,
          headingDeg: (30 - omegaDegS * 20) % 360);
      expect(last!.leanDeg, lessThan(0));
    });
  });

  test('straight line with GPS noise reads as ≈ upright', () {
    final rng = math.Random(42);
    // ±1.5° course jitter and ±0.3 m/s speed jitter at 20 m/s.
    final e = feed(
      300,
      speed: (_) => 20 + (rng.nextDouble() - 0.5) * 0.6,
      heading: (_) => 90 + (rng.nextDouble() - 0.5) * 3,
    );
    final p = e.peaks;
    expect(p.maxLeanDeg, isNotNull, reason: 'measured, not unknown');
    expect(p.maxLeanDeg, lessThan(3.5));
    expect(p.peakLateralG, lessThan(0.06));
    expect(p.peakAccelG ?? 0, lessThan(0.05));
    expect(p.peakBrakeG ?? 0, lessThan(0.05));
  });

  test('below 15 km/h nothing is measured', () {
    // 3 m/s in a tight 5 m circle: a_lat would be 1.8 m/s² — ignored.
    final e =
        feed(30, speed: (_) => 3, heading: (i) => (3 / 5 * 180 / math.pi) * i);
    final p = e.peaks;
    expect(p.maxLeanDeg, isNull);
    expect(p.peakLateralG, isNull);
    expect(p.peakAccelG, isNull);
    expect(p.peakBrakeG, isNull);
  });

  test('a single course flip is rejected, not clamped into a peak', () {
    final e = feed(20, speed: (_) => 20, heading: (i) => i == 10 ? 270 : 90);
    expect(e.peaks.maxLeanDeg, lessThan(1));
  });

  test('a two-fix wobble is not sustained', () {
    // Two fixes of real-looking turn, then straight again: never 3 in a row.
    final e = feed(20, speed: (_) => 20, heading: (i) => i == 10 ? 95 : 90);
    expect(e.peaks.maxLeanDeg, lessThan(1));
  });

  test('clamps to physical limits', () {
    // 40 m/s round a 100 m radius: a_lat = 16 m/s² = 1.63 g, over the clamp
    // but under the glitch threshold.
    const omega = 40 / 100 * 180 / math.pi;
    final e = feed(15, speed: (_) => 40, heading: (i) => omega * i);
    expect(e.peaks.peakLateralG, CorneringEstimator.maxG);
    expect(
        e.peaks.maxLeanDeg, lessThanOrEqualTo(CorneringEstimator.maxLeanDeg));
  });

  test('longitudinal: steady braking and acceleration', () {
    // 25 → 5 m/s at 4 m/s² (≈0.41 g), then back up at 2 m/s² (≈0.20 g).
    final speeds = [
      for (var i = 0; i < 6; i++) 25.0 - 4 * i,
      for (var i = 1; i <= 10; i++) 5.0 + 2 * i,
    ];
    final e = feed(speeds.length, speed: (i) => speeds[i], heading: (_) => 0);
    expect(e.peaks.peakBrakeG, closeTo(4 / kStandardGravity, 0.01));
    expect(e.peaks.peakAccelG, closeTo(2 / kStandardGravity, 0.01));
  });

  test('a gap restarts the history instead of differencing across it', () {
    final e = feed(5, speed: (_) => 20, heading: (_) => 0);
    // 60 s later, heading changed by 90°: across the gap that would be a turn.
    feed(5, into: e, startSecond: 65, speed: (_) => 20, heading: (_) => 90);
    expect(e.peaks.maxLeanDeg, lessThan(1));
  });

  test('reset clears peaks; restartHistory keeps them', () {
    const omega = 15 / 50 * 180 / math.pi;
    final e = feed(10, speed: (_) => 15, heading: (i) => omega * i);
    final before = e.peaks.maxLeanDeg;
    e.restartHistory();
    expect(e.peaks.maxLeanDeg, before);
    e.reset();
    expect(e.peaks.maxLeanDeg, isNull);
  });
}
