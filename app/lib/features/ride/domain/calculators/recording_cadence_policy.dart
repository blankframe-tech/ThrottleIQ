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
/// The cadence policy tracks two separate clocks:
/// 1. `_lastSteadyTimestamp`: regulates steady highway thinning (at most one
///    point per `minPersistIntervalOnSteadyStretches`).
/// 2. `_lastEventTimestamp`: marks forced events (corners, brakes, accels).
///
/// By decoupling the two clocks, a cornering maneuver does not postpone or
/// starve the steady-highway waypoint cadence.
class RecordingCadencePolicy {
  DateTime? _lastSteadyTimestamp;
  DateTime? _lastEventTimestamp;

  /// Returns true if this fix should be added to the point buffer.
  /// [vehicleState] is null before the estimator has produced a state yet
  /// (e.g. the very first fix) — always persist in that case, since there's
  /// nothing yet to justify skipping it.
  bool shouldPersist({
    required DateTime timestamp,
    required VehicleState? vehicleState,
  }) {
    if (vehicleState == null) {
      _lastSteadyTimestamp = timestamp;
      _lastEventTimestamp = timestamp;
      return true;
    }

    final isEvent =
        vehicleState.confidence < SensorConstants.minConfidenceToThinRecording ||
        vehicleState.isCornering ||
        vehicleState.isBraking ||
        vehicleState.isAccelerating;

    if (isEvent) {
      _lastEventTimestamp = timestamp;
      return true;
    }

    final lastSteady = _lastSteadyTimestamp;
    if (lastSteady == null ||
        timestamp.difference(lastSteady) >=
            SensorConstants.minPersistIntervalOnSteadyStretches) {
      _lastSteadyTimestamp = timestamp;
      return true;
    }

    return false;
  }

  DateTime? get lastSteadyTimestamp => _lastSteadyTimestamp;
  DateTime? get lastEventTimestamp => _lastEventTimestamp;

  void reset() {
    _lastSteadyTimestamp = null;
    _lastEventTimestamp = null;
  }
}
