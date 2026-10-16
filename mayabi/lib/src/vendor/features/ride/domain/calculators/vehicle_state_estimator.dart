import 'dart:math';

import '../../../../core/constants/sensor_constants.dart';
import '../entities/vehicle_state.dart';
import 'sensor_validator.dart';

class _TimedValue {
  final DateTime timestamp;
  final double value;
  const _TimedValue(this.timestamp, this.value);
}

/// Fuses GPS + accelerometer + gyroscope samples into a single
/// [VehicleState] per GPS tick.
///
/// This is a **complementary filter**, not a full Kalman/EKF — a
/// deliberate Phase 1 scoping call (see `VEHICLE_STATE_ARCHITECTURE.md`):
/// it's cheap to build and tune without a corpus of real ride logs to
/// validate an EKF's noise tuning against, and degrades gracefully with
/// untuned constants rather than diverging. It's event-driven (each sample
/// carries its own timestamp; no common-clock resampling) rather than
/// clock-tick-driven, which is fine for a complementary filter — real time
/// synchronization only starts to matter once covariance propagation is
/// involved (a Phase 2/EKF concern).
///
/// [speedMs]/[accelerationMs2] stay GPS-derivative (computed upstream by
/// `MotionCalculator` and passed into [addGpsSample]) rather than being
/// re-derived from the IMU — see the class doc on [VehicleState] for why.
/// The IMU (accelerometer + gyroscope) is used here for what it's uniquely
/// good at: heading dead-reckoning between GPS fixes, motion classification,
/// and confidence/imuQuality scoring.
///
/// Heading fusion note: the yaw rate used for dead-reckoning is read
/// directly off the gyroscope's z-axis, which assumes a roughly flat/
/// vertical phone mount (handlebar or dash-mount) — the same pragmatic
/// simplification already used by the existing accelerometer "dominant
/// axis" heuristic elsewhere in this codebase. Inferring true mounting
/// orientation from the gravity vector is a reasonable future improvement,
/// not required for Phase 1.
class VehicleStateEstimator {
  VehicleStateEstimator({SensorValidator? validator})
      : _validator = validator ?? SensorValidator();

  final SensorValidator _validator;

  static const _rejectionWindow = Duration(seconds: 5);
  static const _imuStaleAfter = Duration(seconds: 2);
  static const _maxGyroIntegrationGapSeconds = 1.0;

  VehicleState? _current;
  VehicleState? get currentState => _current;

  // Last accepted GPS fix.
  DateTime? _lastGpsTimestamp;
  double? _lastLat;
  double? _lastLng;
  double? _lastAltitudeM;
  double? _lastSpeedMs;
  double? _lastAccuracyM;
  double? _lastAccelMs2;

  // Heading state.
  double? _fusedHeadingDeg;
  double? _lastYawRateRadS;
  DateTime? _lastGyroTimestamp;

  // Rolling windows for imuQuality.
  final List<_TimedValue> _accelWindow = [];
  DateTime? _lastAccelSampleTimestamp;
  final List<DateTime> _accelRejections = [];
  final List<DateTime> _gyroRejections = [];

  void addGpsSample({
    required DateTime timestamp,
    required double lat,
    required double lng,
    required double speedMs,
    required double accuracyM,
    double? headingDeg,
    double? altitudeM,
    double? accelerationMs2,
  }) {
    final valid = _validator.isValidGpsFix(accuracyM: accuracyM) &&
        _validator.isFreshTimestamp(timestamp, _lastGpsTimestamp);
    if (!valid) return;

    if (headingDeg != null && headingDeg.isFinite) {
      final gpsWeight = accuracyM <= SensorConstants.headingGoodAccuracyThresholdM
          ? SensorConstants.headingGpsWeightGoodAccuracy
          : SensorConstants.headingGpsWeightPoorAccuracy;
      _fusedHeadingDeg = _blendHeading(
        _fusedHeadingDeg ?? headingDeg,
        headingDeg,
        gpsWeight,
      );
    }

    _lastGpsTimestamp = timestamp;
    _lastLat = lat;
    _lastLng = lng;
    _lastAltitudeM = altitudeM;
    _lastSpeedMs = speedMs;
    _lastAccuracyM = accuracyM;
    if (accelerationMs2 != null) _lastAccelMs2 = accelerationMs2;

    _rebuild(timestamp);
  }

  void addAccelSample({
    required DateTime timestamp,
    required double ax,
    required double ay,
    required double az,
  }) {
    final magnitude = sqrt(ax * ax + ay * ay + az * az);
    if (!_validator.isPlausibleAccel(magnitude)) {
      _accelRejections.add(timestamp);
      _pruneWindow(_accelRejections, timestamp);
      return;
    }
    _accelWindow.add(_TimedValue(timestamp, magnitude));
    _lastAccelSampleTimestamp = timestamp;
    _pruneAccelWindow(timestamp);
  }

  void addGyroSample({
    required DateTime timestamp,
    required double gx,
    required double gy,
    required double gz,
  }) {
    final yawRateRadS = gz;
    if (!_validator.isPlausibleYawRate(yawRateRadS)) {
      _gyroRejections.add(timestamp);
      _pruneWindow(_gyroRejections, timestamp);
      return;
    }

    final prevTs = _lastGyroTimestamp;
    if (prevTs != null && _fusedHeadingDeg != null) {
      final dtSeconds = timestamp.difference(prevTs).inMicroseconds / 1e6;
      if (dtSeconds > 0 && dtSeconds < _maxGyroIntegrationGapSeconds) {
        final deltaDeg = yawRateRadS * dtSeconds * (180 / pi);
        _fusedHeadingDeg = _normalizeHeading(_fusedHeadingDeg! + deltaDeg);
      }
    }

    _lastYawRateRadS = yawRateRadS;
    _lastGyroTimestamp = timestamp;
  }

  /// Recomputes confidence/imuQuality/classification against [now] without
  /// requiring a new sample — lets a future periodic caller (e.g. a live UI
  /// refresh timer) observe confidence correctly decay while GPS is stalled
  /// (a tunnel, an urban canyon) between fixes, rather than confidence only
  /// ever being evaluated at the instant a fix arrives (when it's always
  /// maximally fresh by construction). No-ops if there's no fix yet. Not
  /// called by anything this phase — plumbing for later.
  void tick(DateTime now) => _rebuild(now);

  void reset() {
    _current = null;
    _lastGpsTimestamp = null;
    _lastLat = null;
    _lastLng = null;
    _lastAltitudeM = null;
    _lastSpeedMs = null;
    _lastAccuracyM = null;
    _lastAccelMs2 = null;
    _fusedHeadingDeg = null;
    _lastYawRateRadS = null;
    _lastGyroTimestamp = null;
    _accelWindow.clear();
    _lastAccelSampleTimestamp = null;
    _accelRejections.clear();
    _gyroRejections.clear();
  }

  void _rebuild(DateTime now) {
    if (_lastLat == null || _lastLng == null || _lastGpsTimestamp == null) {
      return;
    }

    final imuQuality = _computeImuQuality(now);
    final confidence = _computeConfidence(now, imuQuality);

    final speed = _lastSpeedMs ?? 0;
    final accel = _lastAccelMs2 ?? 0;
    final yaw = _lastYawRateRadS;

    final isMoving = speed > SensorConstants.movingSpeedThresholdMs;
    final isCornering = isMoving &&
        yaw != null &&
        yaw.abs() > SensorConstants.corneringYawRateThresholdRadS;

    _current = VehicleState(
      timestamp: _lastGpsTimestamp!,
      latitude: _lastLat!,
      longitude: _lastLng!,
      altitude: _lastAltitudeM,
      speedMs: speed,
      accelerationMs2: accel,
      headingDeg: _fusedHeadingDeg,
      angularVelocityRadS: yaw,
      confidence: confidence,
      imuQuality: imuQuality,
      isMoving: isMoving,
      isStopped: !isMoving,
      isCornering: isCornering,
      isBraking: accel <= SensorConstants.hardBrakingThreshold,
      isAccelerating: accel >= SensorConstants.rapidAccelThreshold,
      gpsAccuracyM: _lastAccuracyM ?? SensorConstants.maxGpsAccuracyM,
      estimatedRoad: null,
    );
  }

  int _computeConfidence(DateTime now, int imuQuality) {
    if (_lastGpsTimestamp == null || _lastAccuracyM == null) return 0;

    const greatAccuracyM = 3.0;
    final accuracyClamped =
        _lastAccuracyM!.clamp(greatAccuracyM, SensorConstants.maxGpsAccuracyM);
    final accuracyScore = 50 *
        (1 -
            (accuracyClamped - greatAccuracyM) /
                (SensorConstants.maxGpsAccuracyM - greatAccuracyM));

    const freshSeconds = 2.0;
    const staleSeconds = 10.0;
    final ageSeconds =
        now.difference(_lastGpsTimestamp!).inMilliseconds / 1000;
    final recencyScore = ageSeconds <= freshSeconds
        ? 20.0
        : ageSeconds >= staleSeconds
            ? 0.0
            : 20 * (1 - (ageSeconds - freshSeconds) / (staleSeconds - freshSeconds));

    final imuScore = imuQuality / 100 * 30;

    return (accuracyScore + recencyScore + imuScore).round().clamp(0, 100);
  }

  int _computeImuQuality(DateTime now) {
    _pruneAccelWindow(now);
    _pruneWindow(_accelRejections, now);
    _pruneWindow(_gyroRejections, now);

    var quality = 100;

    final accelStale = _lastAccelSampleTimestamp == null ||
        now.difference(_lastAccelSampleTimestamp!) > _imuStaleAfter;
    if (accelStale) quality -= 40;

    quality -= (_accelRejections.length * 5).clamp(0, 30);
    quality -= (_gyroRejections.length * 5).clamp(0, 20);

    if (_accelWindow.length >= 5) {
      final values = _accelWindow.map((s) => s.value).toList();
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          values.length;
      if (variance < 0.0001) quality -= 20;
    }

    return quality.clamp(0, 100);
  }

  void _pruneAccelWindow(DateTime now) {
    _accelWindow.removeWhere((s) => now.difference(s.timestamp) > _rejectionWindow);
  }

  void _pruneWindow(List<DateTime> timestamps, DateTime now) {
    timestamps.removeWhere((t) => now.difference(t) > _rejectionWindow);
  }

  double _blendHeading(double from, double to, double weight) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return _normalizeHeading(from + weight * diff);
  }

  double _normalizeHeading(double deg) {
    var d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }
}
