import 'package:sensors_plus/sensors_plus.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/services/haptic_service.dart';
import 'package:throttleiq/features/ride/domain/calculators/accel_axis_calibrator.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/vehicle_state_estimator.dart';

/// Coordinates IMU sensor streams (accelerometer, gyroscope), axis calibration,
/// low-pass filtered longitudinal acceleration, vehicle state estimation,
/// and (behind [impactDetectionEnabled]) raw-IMU crash detection.
///
/// Once [axisCalibrator] is calibrated, this is the single owner of the
/// hard-brake / rapid-accel counts; before that the GPS path in
/// [EventDetector.detect] owns them (§78.3, §78.13).
class SensorFusionCoordinator {
  SensorFusionCoordinator({
    AccelAxisCalibrator? axisCalibrator,
    VehicleStateEstimator? estimator,
    ImpactDetector? impactDetector,
    bool impactDetectionEnabled = SensorConstants.impactDetectorLiveEnabled,
    this.onImpactCrash,
    Future<void> Function()? alertHaptic,
  })  : _alertHaptic = alertHaptic ?? HapticService.alertPattern,
        _axisCalibrator = axisCalibrator ?? AccelAxisCalibrator(),
        _estimator = estimator ?? VehicleStateEstimator(),
        _impactDetector = impactDetector ?? ImpactDetector(),
        _impactDetectionEnabled = impactDetectionEnabled;

  final AccelAxisCalibrator _axisCalibrator;
  final VehicleStateEstimator _estimator;
  final ImpactDetector _impactDetector;
  final bool _impactDetectionEnabled;
  final Future<void> Function() _alertHaptic;

  /// Called when [ImpactDetector] confirms a crash. Only ever called when
  /// [impactDetectionEnabled]; the caller applies the confidence gate.
  void Function(CrashSignal signal)? onImpactCrash;

  double _rawAccelSumX = 0;
  double _rawAccelSumY = 0;
  double _rawAccelSumZ = 0;
  int _rawAccelSampleCount = 0;

  double _filteredAccel = 0;
  static const double _alpha = 0.1;

  DateTime? _lastSensorEvent;
  static const Duration _eventCooldown = Duration(seconds: 2);

  // Edge-trigger state (§78.3): an event counts once on crossing the
  // threshold, then re-arms only after the filtered signal comes back past
  // the re-arm level. Without this, every 50 ms sample of a held brake
  // counted as another hard brake.
  bool _brakeArmed = true;
  bool _accelArmed = true;
  DateTime? _lastSensorUiPush;
  static const Duration _sensorUiPushInterval = Duration(milliseconds: 200);

  double get filteredAccel => _filteredAccel;
  int get confidence => _estimator.currentState?.confidence ?? 0;
  VehicleStateEstimator get estimator => _estimator;
  AccelAxisCalibrator get axisCalibrator => _axisCalibrator;
  ImpactDetector get impactDetector => _impactDetector;
  bool get impactDetectionEnabled => _impactDetectionEnabled;

  void reset() {
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;
    _filteredAccel = 0;
    _lastSensorEvent = null;
    _lastSensorUiPush = null;
    _brakeArmed = true;
    _accelArmed = true;
    _axisCalibrator.reset();
    _estimator.reset();
    _impactDetector.reset();
  }

  /// Feeds an accelerometer sample that *includes* gravity, used only for
  /// the impact detector's orientation check. No-op while disabled.
  void onGravityEvent(AccelerometerEvent event, {DateTime? at}) {
    if (!_impactDetectionEnabled) return;
    _impactDetector.addGravitySample(
        at ?? DateTime.now(), event.x, event.y, event.z);
  }

  /// Feeds an accepted GPS fix's speed to the impact detector, which needs
  /// it to confirm a stop after a spike. No-op while disabled.
  void onGpsSpeed(DateTime at, double speedMs) {
    if (!_impactDetectionEnabled) return;
    final signal = _impactDetector.addSpeed(at, speedMs);
    if (signal != null) onImpactCrash?.call(signal);
  }

  /// Feeds gyroscope event to VehicleStateEstimator.
  void onGyroEvent(GyroscopeEvent event) {
    _estimator.addGyroSample(
      timestamp: DateTime.now(),
      gx: event.x,
      gy: event.y,
      gz: event.z,
    );
  }

  /// Processes raw accelerometer sample: feeds the impact detector (raw,
  /// before any filtering), the IMU quality pipeline, axis calibration sums,
  /// applies the low-pass filter, and triggers brake/accel alerts.
  ///
  /// [at] defaults to now; tests pass it to drive time deterministically.
  void onAccelEvent({
    required UserAccelerometerEvent event,
    required EventDetector detector,
    required void Function(double filteredAccel) onUiPush,
    required void Function(RideAlert alert) onAlertTriggered,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();

    // Raw magnitude, BEFORE the α=0.1 low-pass below — which would flatten a
    // 50-100 ms impact spike to a tenth of its height (§78.1).
    if (_impactDetectionEnabled) {
      final signal =
          _impactDetector.addSample(now, event.x, event.y, event.z);
      if (signal != null) onImpactCrash?.call(signal);
    }

    _estimator.addAccelSample(
      timestamp: now,
      ax: event.x,
      ay: event.y,
      az: event.z,
    );

    _rawAccelSumX += event.x;
    _rawAccelSumY += event.y;
    _rawAccelSumZ += event.z;
    _rawAccelSampleCount++;

    final signedMagnitude =
        _axisCalibrator.signedLongitudinalAccelMs2(event.x, event.y, event.z);

    _filteredAccel = _alpha * signedMagnitude + (1 - _alpha) * _filteredAccel;

    final dueForUiPush = _lastSensorUiPush == null ||
        now.difference(_lastSensorUiPush!) >= _sensorUiPushInterval;
    if (dueForUiPush) {
      _lastSensorUiPush = now;
      onUiPush(_filteredAccel);
    }

    // Before calibration the projection falls back to the dominant axis at
    // full magnitude, so a pothole's vertical jolt reads as braking (§78.13).
    // The GPS path owns the counts until then.
    if (!_axisCalibrator.isCalibrated) return;

    if (_filteredAccel > SensorConstants.hardBrakingRearmThreshold) {
      _brakeArmed = true;
    }
    if (_filteredAccel < SensorConstants.rapidAccelRearmThreshold) {
      _accelArmed = true;
    }

    final cooldownOk = _lastSensorEvent == null ||
        now.difference(_lastSensorEvent!) >= _eventCooldown;
    if (!cooldownOk) return;

    RideAlert? sensorAlert;
    if (_brakeArmed && _filteredAccel < SensorConstants.hardBrakingThreshold) {
      _brakeArmed = false;
      detector.hardBrakeCount++;
      sensorAlert = RideAlert.hardBraking;
    } else if (_accelArmed &&
        _filteredAccel > SensorConstants.rapidAccelThreshold) {
      _accelArmed = false;
      detector.rapidAccelCount++;
      sensorAlert = RideAlert.rapidAccel;
    }

    if (sensorAlert != null) {
      // Refreshed on every counted event, not only when the UI alert
      // changes — that was what let a repeated alert of the same kind skip
      // the cooldown entirely.
      _lastSensorEvent = now;
      _alertHaptic();
      onAlertTriggered(sensorAlert);
    }
  }

  /// Pairs the current GPS fix acceleration with the mean raw accelerometer
  /// readings accumulated since the previous fix, then resets the accumulator.
  void pairGpsAccel(double? gpsAccelMs2) {
    if (_rawAccelSampleCount > 0 && gpsAccelMs2 != null) {
      _axisCalibrator.addSample(
        ax: _rawAccelSumX / _rawAccelSampleCount,
        ay: _rawAccelSumY / _rawAccelSampleCount,
        az: _rawAccelSumZ / _rawAccelSampleCount,
        gpsAccelMs2: gpsAccelMs2,
      );
    }
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;
  }
}
