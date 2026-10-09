import '../../../../core/constants/sensor_constants.dart';
import 'average_speed.dart';
import 'cornering_estimator.dart';

/// The `rides` summary columns for a finished ride, from the recorder's
/// in-memory running totals.
///
/// Written by both `stopRide` and the crash path. The crash path used to
/// write only `status` and `end_time`, leaving a crash ride with no
/// distance, duration, speeds or counts (§69.O10) — so this is pure and
/// shared rather than inlined in one of them.
Map<String, dynamic> buildFinalRideStats({
  required DateTime endTime,
  required double distanceM,
  required double maxSpeedMs,
  required double speedSum,
  required int speedCount,
  required int movingMilliseconds,
  required int movingSeconds,
  required int durationSeconds,
  required int hardBrakeCount,
  required int rapidAccelCount,
  required int highJerkCount,
  required int overspeedCount,
  CorneringPeaks? corneringPeaks,
  ({double gainM, double lossM})? elevation,
}) {
  var effectiveMax = maxSpeedMs;
  if (effectiveMax > SensorConstants.maxPlausibleSpeedMs) {
    effectiveMax = SensorConstants.maxPlausibleSpeedMs;
  }

  final derivedAvg = movingMilliseconds > 0
      ? averageSpeedMs(
          distanceM: distanceM,
          movingSeconds: movingSeconds,
          maxSpeedMs: effectiveMax > 0 ? effectiveMax : null,
        )
      : (speedCount > 0 ? speedSum / speedCount : 0.0);

  // Physical invariant: maximum speed can never be less than average speed.
  // If max speed was unrecorded (e.g. zero GPS Doppler speed) but the vehicle moved,
  // ensure max speed is at least the average speed.
  if (effectiveMax < derivedAvg &&
      derivedAvg <= SensorConstants.maxPlausibleSpeedMs) {
    effectiveMax = derivedAvg;
  }

  // Sanity check: average speed can never physically exceed max speed.
  // If anomalies occur (e.g. truncated moving time), fallback to distance/duration or maxSpeed.
  final avgSpeed = (effectiveMax > 0 && derivedAvg > effectiveMax)
      ? (durationSeconds > 0
          ? (distanceM / durationSeconds).clamp(0.0, effectiveMax)
          : effectiveMax)
      : derivedAvg;

  return {
    'end_time': endTime.toIso8601String(),
    'distance_m': distanceM,
    'avg_speed_ms': avgSpeed,
    'max_speed_ms': effectiveMax,
    'duration_s': durationSeconds,
    'moving_s': movingSeconds,
    'hard_brake_count': hardBrakeCount,
    'rapid_accel_count': rapidAccelCount,
    'high_jerk_count': highJerkCount,
    'overspeed_count': overspeedCount,
    // Schema v26. Null peaks mean the estimator never saw a usable stretch
    // (a ride that never got above walking pace); null elevation means the
    // altitude data couldn't support a figure, or the caller (the crash
    // path) didn't read the points — the backfill picks that up later.
    'max_lean_deg': corneringPeaks?.maxLeanDeg,
    'peak_lateral_g': corneringPeaks?.peakLateralG,
    'peak_accel_g': corneringPeaks?.peakAccelG,
    'peak_brake_g': corneringPeaks?.peakBrakeG,
    if (elevation != null) 'elevation_gain_m': elevation.gainM,
    if (elevation != null) 'elevation_loss_m': elevation.lossM,
  };
}
