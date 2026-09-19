import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/features/ride/domain/calculators/final_ride_stats.dart';

/// §69.O10: the stats stopRide writes, now shared with the crash path.
void main() {
  Map<String, dynamic> build({
    double distanceM = 6000,
    double maxSpeedMs = 20,
    int movingSeconds = 600,
    int durationSeconds = 700,
    double speedSum = 0,
    int speedCount = 0,
  }) =>
      buildFinalRideStats(
        endTime: DateTime(2026, 9, 20, 10),
        distanceM: distanceM,
        maxSpeedMs: maxSpeedMs,
        speedSum: speedSum,
        speedCount: speedCount,
        movingMilliseconds: movingSeconds * 1000,
        movingSeconds: movingSeconds,
        durationSeconds: durationSeconds,
        hardBrakeCount: 2,
        rapidAccelCount: 3,
        highJerkCount: 1,
      );

  test('writes every summary column the ride summary reads', () {
    final stats = build();
    expect(stats.keys, containsAll(<String>[
      'end_time', 'distance_m', 'avg_speed_ms', 'max_speed_ms', 'duration_s',
      'moving_s', 'hard_brake_count', 'rapid_accel_count', 'high_jerk_count',
    ]));
    expect(stats.containsKey('status'), isFalse,
        reason: 'callers choose the status (completed vs crash)');
    expect(stats['distance_m'], 6000);
    expect(stats['avg_speed_ms'], closeTo(10, 1e-9));
    expect(stats['duration_s'], 700);
    expect(stats['hard_brake_count'], 2);
  });

  test('caps an implausible max speed', () {
    expect(build(maxSpeedMs: 500)['max_speed_ms'],
        SensorConstants.maxPlausibleSpeedMs);
  });

  test('max is raised to at least the average', () {
    final stats = build(maxSpeedMs: 0);
    expect(stats['max_speed_ms'], greaterThanOrEqualTo(stats['avg_speed_ms']));
  });

  test('no moving time falls back to the mean sample speed', () {
    final stats = build(movingSeconds: 0, speedSum: 30, speedCount: 3);
    expect(stats['avg_speed_ms'], 10);
  });

  test('a crash merge keeps the stats and overrides status', () {
    final row = {...build(), 'status': 'crash'};
    expect(row['status'], 'crash');
    expect(row['distance_m'], 6000);
  });
}
