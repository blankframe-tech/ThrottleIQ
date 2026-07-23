import '../../../../core/constants/sensor_constants.dart';
import '../entities/vehicle_state.dart';

/// Decides which GPS fixes actually get **persisted** to `ride_points` —
/// Phase 1.5 of the vehicle-state roadmap ("record less on a confident
/// straight highway, more mid-corner").
///
/// This only ever thins what's written to disk. It does not, and must not,
/// affect: the live in-ride map (still appends every fix, unthinned — this
/// only changes the post-ride replay/summary/share polyline, reconstructed
/// from `ride_points`), the ride-level aggregate stats (distance/avg-speed/
/// max-speed must keep summing every GPS fix regardless of what gets
/// persisted), or `MotionCalculator`'s accel/jerk derivative chain (which
/// must keep seeing every consecutive fix — skipping fixes in *that* chain
/// would corrupt the deltas). The caller is responsible for keeping those
/// paths unconditional; this class only answers "should this one fix be
/// written to the point buffer."
///
/// Deliberately conservative: a fix is only eligible to be skipped when
/// [VehicleState.confidence] clears a high floor AND none of
/// cornering/braking/accelerating are true — anything "interesting," or
/// anything the fusion engine isn't confident about, is always kept.
///
/// The throttle itself is a plain "at most one persisted point per interval"
/// rate limiter measured from the last point persisted for *any* reason —
/// it doesn't track a separate clock per reason. A forced-through event
/// point (a corner, say) resets the same clock a throttled steady point
/// would have, rather than the two being tracked independently.
class RecordingCadencePolicy {
  DateTime? _lastPersistedTimestamp;

  /// Returns true if this fix should be added to the point buffer.
  /// [vehicleState] is null before the estimator has produced a state yet
  /// (e.g. the very first fix) — always persist in that case, since there's
  /// nothing yet to justify skipping it.
  bool shouldPersist({
    required DateTime timestamp,
    required VehicleState? vehicleState,
  }) {
    if (vehicleState == null) {
      _lastPersistedTimestamp = timestamp;
      return true;
    }

    final eligibleForThinning =
        vehicleState.confidence >= SensorConstants.minConfidenceToThinRecording &&
        !vehicleState.isCornering &&
        !vehicleState.isBraking &&
        !vehicleState.isAccelerating;

    if (!eligibleForThinning) {
      _lastPersistedTimestamp = timestamp;
      return true;
    }

    final last = _lastPersistedTimestamp;
    if (last == null ||
        timestamp.difference(last) >= SensorConstants.minPersistIntervalOnSteadyStretches) {
      _lastPersistedTimestamp = timestamp;
      return true;
    }

    return false;
  }

  void reset() {
    _lastPersistedTimestamp = null;
  }
}
