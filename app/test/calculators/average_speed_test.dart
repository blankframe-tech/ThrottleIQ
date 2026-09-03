import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/average_speed.dart';

final _t0 = DateTime(2026, 8, 1, 9, 0, 0);
SpeedSample _s(int atSecond, double speedMs) =>
    (time: _t0.add(Duration(seconds: atSecond)), speedMs: speedMs);

void main() {
  group('averageSpeedMs', () {
    test('is distance over moving time', () {
      expect(averageSpeedMs(distanceM: 1000, movingSeconds: 100), 10.0);
      expect(averageSpeedMs(distanceM: 500, movingSeconds: 50), 10.0);
    });

    test('never divides by zero', () {
      expect(averageSpeedMs(distanceM: 1000, movingSeconds: 0), 0);
      expect(averageSpeedMs(distanceM: 1000, movingSeconds: -5), 0);
    });

    test('clamps to maxSpeedMs when provided', () {
      // 1000m in 10s = 100 m/s, but max is 20 m/s -> clamped to 20 m/s
      expect(
        averageSpeedMs(distanceM: 1000, movingSeconds: 10, maxSpeedMs: 20),
        20.0,
      );
      // Within ceiling -> untouched
      expect(
        averageSpeedMs(distanceM: 1000, movingSeconds: 100, maxSpeedMs: 20),
        10.0,
      );
    });
  });

  group('movingSeconds', () {
    test('needs at least two fixes', () {
      expect(movingSeconds(const []), 0);
      expect(movingSeconds([_s(0, 10)]), 0);
    });

    test('counts the gaps between moving fixes', () {
      // Fixes every second, all moving: 4 gaps between 5 samples.
      final samples = [for (var i = 0; i < 5; i++) _s(i, 10)];
      expect(movingSeconds(samples), 4);
    });

    test('excludes time spent stopped', () {
      // 10 s moving, then 10 s stopped at a light, then 10 s moving.
      final samples = <SpeedSample>[
        for (var i = 0; i <= 10; i++) _s(i, 10),
        for (var i = 11; i <= 20; i++) _s(i, 0),
        for (var i = 21; i <= 30; i++) _s(i, 10),
      ];
      // 10 one-second gaps across the opening run (t=1..10), then nothing
      // while stopped, then 10 more across the closing run (t=21..30 — the
      // gap re-entering motion at t=21 is the first of those, not an extra).
      expect(movingSeconds(samples), 20);
    });

    // The headline behaviour change: idling at lights used to drag the mean
    // down. Moving-time average should be ~double the naive mean for a ride
    // that was stopped half the time.
    test('a ride stopped half the time reports roughly double the naive mean', () {
      final samples = <SpeedSample>[
        for (var i = 0; i < 60; i++) _s(i, 20),
        for (var i = 60; i < 120; i++) _s(i, 0),
      ];
      final moving = movingSeconds(samples);
      const distanceM = 20.0 * 59; // 20 m/s across the 59 moving gaps

      final naiveMean =
          samples.map((s) => s.speedMs).reduce((a, b) => a + b) / samples.length;
      final movingAvg =
          averageSpeedMs(distanceM: distanceM, movingSeconds: moving);

      expect(naiveMean, closeTo(10, 0.2));
      expect(movingAvg, closeTo(20, 0.2));
      expect(movingAvg / naiveMean, closeTo(2, 0.1));
    });

    test('ignores implausibly long gaps (tunnel / suspended app)', () {
      // A 10-minute hole between two moving fixes must not count as moving.
      final samples = [_s(0, 10), _s(600, 10), _s(601, 10)];
      expect(movingSeconds(samples), 1);
    });

    test('respects a custom max gap', () {
      final samples = [_s(0, 10), _s(30, 10)];
      expect(movingSeconds(samples, maxGapSeconds: 60), 30);
      expect(movingSeconds(samples, maxGapSeconds: 10), 0);
    });

    test('respects a custom moving threshold', () {
      final samples = [_s(0, 3), _s(1, 3), _s(2, 3)];
      expect(movingSeconds(samples, thresholdMs: 1), 2);
      expect(movingSeconds(samples, thresholdMs: 5), 0);
    });

    test('ignores out-of-order or duplicate timestamps', () {
      final samples = [_s(10, 10), _s(5, 10), _s(5, 10)];
      expect(movingSeconds(samples), 0);
    });

    test('a fully stopped ride has no moving time', () {
      final samples = [for (var i = 0; i < 30; i++) _s(i, 0)];
      expect(movingSeconds(samples), 0);
    });

    test('accumulates sub-second fix intervals accurately (does not truncate to 0)', () {
      // 10 fixes arriving every 450ms (typical at 40 km/h with 5m filter) = 4.05s moving
      final t0 = DateTime(2026, 8, 1, 9, 0, 0);
      final samples = [
        for (var i = 0; i < 10; i++)
          (time: t0.add(Duration(milliseconds: i * 450)), speedMs: 11.0),
      ];
      // In the old code, every 450ms gap evaluated to inSeconds == 0, resulting in 0s!
      // In the new code, 9 gaps of 450ms = 4050ms -> 4s.
      expect(movingSeconds(samples), 4);
    });
  });
}
