import 'package:sensors_plus/sensors_plus.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/services/haptic_service.dart';
import 'package:throttleiq/features/ride/domain/calculators/accel_axis_calibrator.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/vehicle_state_estimator.dart';

/// Coordinates IMU sensor streams (accelerometer, gyroscope), axis calibration,
/// low-pass filtered longitudinal acceleration, and vehicle state estimation.
class SensorFusionCoordinator {
  SensorFusionCoordinator({
    AccelAxisCalibrator? axisCalibrator,
    VehicleStateEstimator? estimator,
  })  : _axisCalibrator = axisCalibrator ?? AccelAxisCalibrator(),
        _estimator = estimator ?? VehicleStateEstimator();

  final AccelAxisCalibrator _axisCalibrator;
  final VehicleStateEstimator _estimator;

  double _rawAccelSumX = 0;
  double _rawAccelSumY = 0;
  double _rawAccelSumZ = 0;
  int _rawAccelSampleCount = 0;

  double _filteredAccel = 0;
  static const double _alpha = 0.1;

  DateTime? _lastSensorEvent;
  DateTime? _lastSensorUiPush;
  static const Duration _sensorUiPushInterval = Duration(milliseconds: 200);

  double get filteredAccel => _filteredAccel;
  int get confidence => _estimator.currentState?.confidence ?? 0;
  VehicleStateEstimator get estimator => _estimator;
  AccelAxisCalibrator get axisCalibrator => _axisCalibrator;

  void reset() {
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;
    _filteredAccel = 0;
    _lastSensorEvent = null;
    _lastSensorUiPush = null;
    _axisCalibrator.reset();
    _estimator.reset();
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

  /// Processes raw accelerometer sample: feeds IMU quality pipeline, updates
  /// axis calibration sums, applies low-pass filter, and triggers alerts.
  void onAccelEvent({
    required UserAccelerometerEvent event,
    required EventDetector detector,
    required RideAlert currentActiveAlert,
    required void Function(double filteredAccel) onUiPush,
    required void Function(RideAlert alert) onAlertTriggered,
  }) {
    _estimator.addAccelSample(
      timestamp: DateTime.now(),
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

    final nowSample = DateTime.now();
    final dueForUiPush = _lastSensorUiPush == null ||
        nowSample.difference(_lastSensorUiPush!) >= _sensorUiPushInterval;
    if (dueForUiPush) {
      _lastSensorUiPush = nowSample;
      onUiPush(_filteredAccel);
    }

    final now = DateTime.now();
    final cooldownOk = _lastSensorEvent == null ||
        now.difference(_lastSensorEvent!).inSeconds >= 2;

    if (!cooldownOk) return;

    RideAlert? sensorAlert;
    if (_filteredAccel < SensorConstants.hardBrakingThreshold) {
      detector.hardBrakeCount++;
      sensorAlert = RideAlert.hardBraking;
    } else if (_filteredAccel > SensorConstants.rapidAccelThreshold) {
      detector.rapidAccelCount++;
      sensorAlert = RideAlert.rapidAccel;
    }

    if (sensorAlert != null && sensorAlert != currentActiveAlert) {
      _lastSensorEvent = now;
      HapticService.alertPattern();
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
