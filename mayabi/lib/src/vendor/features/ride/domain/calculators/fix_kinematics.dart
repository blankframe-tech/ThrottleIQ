import 'dart:math' as math;

import '../../../../core/constants/sensor_constants.dart';

/// What one GPS fix contributes to a ride, once the sanity rules have run.
typedef FixKinematics = ({
  double speedMs,
  double distanceDeltaM,
  double? acceleration,
  double? jerk,

  /// This fix's speed was cut back by the physical-acceleration limit. The
  /// caller carries it to the next fix as [PrevFix.clamped].
  bool clamped,
});

/// The previous fix as the kinematics rules need it: its final (clamped)
/// speed, the acceleration it was stored with, and whether its speed was
/// clamped.
typedef PrevFix = ({double speedMs, double? acceleration, bool clamped});

/// Builds a [PrevFix] from a stored point's values.
PrevFix prevFixOf(double speedMs, {double? acceleration, bool clamped = false}) =>
    (speedMs: speedMs, acceleration: acceleration, clamped: clamped);

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
/// [rawDistanceM]/[deltaTSeconds] are what `MotionCalculator.calculate`
/// returned against [prev].
///
/// Acceleration and jerk are derived here, from the final clamped speeds, not
/// taken from the raw Doppler speeds (issues §101.R5): a single spike
/// (10 -> 40 -> 10 m/s) used to read as +30 then -30 m/s^2, a phantom hard
/// brake. They are null when there is no usable interval (first fix, or
/// under 0.1 s, where dividing inflates noise 50x), when this fix was
/// clamped, and for the fix right after a clamped one (the rebound).
FixKinematics evaluateFix({
  required double rawSpeedMs,
  required PrevFix? prev,
  required double rawDistanceM,
  required double deltaTSeconds,
  required double accuracyM,
}) {
  var distDelta = prev == null ? 0.0 : rawDistanceM;
  final deltaT = prev == null ? 0.0 : deltaTSeconds;
  double? accel;
  double? jrk;
  var clamped = false;

  final hasValidDeltaT = deltaT >= 0.1;
  final candidateDerivedSpeed = hasValidDeltaT ? distDelta / deltaT : 0.0;
  final isPlausibleDerived =
      candidateDerivedSpeed <= SensorConstants.maxPlausibleSpeedMs;
  // A NaN/Infinity Doppler speed is treated as "none" (derived-speed branch).
  final hasRawSpeed = rawSpeedMs.isFinite &&
      rawSpeedMs >= SensorConstants.unreliableSpeedFallbackThresholdMs &&
          rawSpeedMs <= SensorConstants.maxPlausibleSpeedMs;

  double speedMs;
  if (hasRawSpeed) {
    if (prev != null && hasValidDeltaT) {
      final maxAllowedSpeed =
          prev.speedMs + (SensorConstants.maxPhysicalAccelMs2 * deltaT);
      clamped = rawSpeedMs > maxAllowedSpeed && prev.speedMs > 0;
      speedMs = clamped ? maxAllowedSpeed : rawSpeedMs;
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
      clamped = candidateDerivedSpeed > maxAllowedSpeed && prev.speedMs > 0;
      speedMs = clamped ? maxAllowedSpeed : candidateDerivedSpeed;
    } else {
      speedMs = candidateDerivedSpeed;
    }
  } else {
    speedMs = 0.0;
    distDelta = 0.0;
    accel = 0.0;
    jrk = 0.0;
    return (
      speedMs: speedMs,
      distanceDeltaM: distDelta,
      acceleration: accel,
      jerk: jrk,
      clamped: false,
    );
  }

  if (prev != null && hasValidDeltaT && !clamped && !prev.clamped) {
    accel = (speedMs - prev.speedMs) / deltaT;
    if (prev.acceleration != null) {
      jrk = (accel - prev.acceleration!) / deltaT;
    }
  }

  return (
    speedMs: speedMs,
    distanceDeltaM: distDelta,
    acceleration: accel,
    jerk: jrk,
    clamped: clamped,
  );
}
