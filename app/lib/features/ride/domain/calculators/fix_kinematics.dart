import 'dart:math' as math;

import '../../../../core/constants/sensor_constants.dart';

/// What one GPS fix contributes to a ride, once the sanity rules have run.
typedef FixKinematics = ({
  double speedMs,
  double distanceDeltaM,
  double? acceleration,
  double? jerk,
});

/// The previous fix as the kinematics rules need it.
typedef PrevFix = ({double speedMs});

/// Most distance a fix with a usable Doppler speed may add (§90.C12).
///
/// A Doppler speed says how fast the phone was moving; it says nothing about
/// whether the *position* is right. A multipath jump inside the 25 m accuracy
/// gate used to be credited in full because its speed looked plausible. The
/// cap is the faster of the two end speeds over the interval, with 50%
/// headroom for speed changing between fixes, plus the fix's own accuracy
/// radius so honest jitter is never clipped.
double dopplerDistanceCapM({
  required double rawSpeedMs,
  required double prevSpeedMs,
  required double deltaTSeconds,
  required double accuracyM,
}) {
  final dt = deltaTSeconds < 0 ? 0.0 : deltaTSeconds;
  final acc = accuracyM.isFinite && accuracyM > 0 ? accuracyM : 0.0;
  return math.max(rawSpeedMs, prevSpeedMs) * dt * 1.5 + acc;
}

/// The per-fix speed/distance decision shared by the live recorder
/// (`RideRecordingNotifier._onPosition`) and the auto-detection replay
/// (`AutoRideReconciler`). Pulled out so both apply the same rules and so the
/// rules are testable without a platform GPS stream.
///
/// [prev] is null for the first fix of a segment (ride start, or the first
/// fix after a resume): such a fix contributes speed but no distance.
/// [rawDistanceM]/[deltaTSeconds]/[acceleration]/[jerk] are what
/// `MotionCalculator.calculate` returned against [prev].
FixKinematics evaluateFix({
  required double rawSpeedMs,
  required PrevFix? prev,
  required double rawDistanceM,
  required double deltaTSeconds,
  required double accuracyM,
  double? acceleration,
  double? jerk,
}) {
  var distDelta = prev == null ? 0.0 : rawDistanceM;
  final deltaT = prev == null ? 0.0 : deltaTSeconds;
  double? accel = acceleration;
  double? jrk = jerk;

  final hasValidDeltaT = deltaT >= 0.1;
  final candidateDerivedSpeed = hasValidDeltaT ? distDelta / deltaT : 0.0;
  final isPlausibleDerived =
      candidateDerivedSpeed <= SensorConstants.maxPlausibleSpeedMs;
  final hasRawSpeed =
      rawSpeedMs >= SensorConstants.unreliableSpeedFallbackThresholdMs &&
          rawSpeedMs <= SensorConstants.maxPlausibleSpeedMs;

  double speedMs;
  if (hasRawSpeed) {
    if (prev != null && hasValidDeltaT) {
      final maxAllowedSpeed =
          prev.speedMs + (SensorConstants.maxPhysicalAccelMs2 * deltaT);
      speedMs = (rawSpeedMs > maxAllowedSpeed && prev.speedMs > 0)
          ? maxAllowedSpeed
          : rawSpeedMs;
    } else {
      speedMs = rawSpeedMs;
    }
    if (prev != null) {
      final cap = dopplerDistanceCapM(
        rawSpeedMs: rawSpeedMs,
        prevSpeedMs: prev.speedMs,
        deltaTSeconds: deltaT,
        accuracyM: accuracyM,
      );
      if (distDelta > cap) distDelta = cap;
    }
  } else if (hasValidDeltaT &&
      isPlausibleDerived &&
      distDelta > 10.0 &&
      candidateDerivedSpeed >=
          SensorConstants.unreliableSpeedFallbackThresholdMs) {
    if (prev != null) {
      final maxAllowedSpeed =
          prev.speedMs + (SensorConstants.maxPhysicalAccelMs2 * deltaT);
      speedMs = (candidateDerivedSpeed > maxAllowedSpeed && prev.speedMs > 0)
          ? maxAllowedSpeed
          : candidateDerivedSpeed;
    } else {
      speedMs = candidateDerivedSpeed;
    }
  } else {
    speedMs = 0.0;
    distDelta = 0.0;
    accel = 0.0;
    jrk = 0.0;
  }

  return (
    speedMs: speedMs,
    distanceDeltaM: distDelta,
    acceleration: accel,
    jerk: jrk,
  );
}
