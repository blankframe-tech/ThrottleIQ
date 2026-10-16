import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/services/haptic_service.dart';
import 'package:throttleiq/features/ride/domain/calculators/accel_axis_calibrator.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_detector.dart';
import 'package:throttleiq/features/ride/domain/calculators/impact_window_recorder.dart';
import 'package:throttleiq/features/ride/domain/calculators/vehicle_state_estimator.dart';

/// Coordinates IMU sensor streams (accelerometer, gyroscope), axis calibration,
/// low-pass filtered longitudinal acceleration, vehicle state estimation,
/// and (behind [impactDetectionEnabled]) shadow-mode crash detection.
///
/// Once [axisCalibrator] is calibrated, this is the single owner of the
/// hard-brake / rapid-accel counts; before that the GPS path in
/// [EventDetector.detect] owns them (§78.3, §78.13).
class SensorFusionCoordinator {
  SensorFusionCoordinator({
    AccelAxisCalibrator? axisCalibrator,
    VehicleStateEstimator? estimator,
    ImpactDetector? impactDetector,
    ImpactWindowRecorder? windowRecorder,
    bool impactDetectionEnabled = SensorConstants.impactShadowEnabled,
    bool crashAlertsEnabled = SensorConstants.crashAlertsEnabled,
    this.onImpactCrash,
    this.onImpactCandidate,
    Future<void> Function()? alertHaptic,
    math.Random? random,
  })  : _alertHaptic = alertHaptic ?? HapticService.alertPattern,
        _axisCalibrator = axisCalibrator ?? AccelAxisCalibrator(),
        _estimator = estimator ?? VehicleStateEstimator(),
        _impactDetector = impactDetector ?? ImpactDetector(),
        _windowRecorder = windowRecorder ?? ImpactWindowRecorder(),
        _impactDetectionEnabled = impactDetectionEnabled,
        _crashAlertsEnabled = crashAlertsEnabled,
        _random = random ?? math.Random() {
    _impactDetector.onCandidate = _onCandidate;
  }

  final AccelAxisCalibrator _axisCalibrator;
  final VehicleStateEstimator _estimator;
  final ImpactDetector _impactDetector;
  final ImpactWindowRecorder _windowRecorder;
  final bool _impactDetectionEnabled;
  final bool _crashAlertsEnabled;
  final Future<void> Function() _alertHaptic;
  final math.Random _random;

  /// Called when [ImpactDetector] reaches tier 2. Only ever called when
  /// [crashAlertsEnabled]; the caller applies the confidence gate.
  void Function(CrashSignal signal)? onImpactCrash;

  /// Called once per resolved impact while [impactDetectionEnabled], with its
  /// sensor window when one was kept (see [maxWindowsPerRide]).
  void Function(ImpactCandidate candidate, Uint8List? window)?
      onImpactCandidate;

  /// Per-ride caps (crash-detection plan §8): a rough road can produce a
  /// stream of tier-0 impacts, and Spark has 1 GiB in total.
  static const int maxCandidatesPerRide = 20;
  static const int maxWindowsPerRide = 5;

  /// Share of tier-0 impacts saved with their window anyway, so the false
  /// alarms can be studied too.
  static const double tier0WindowShare = 0.10;

  int _candidatesThisRide = 0;
  int _windowsThisRide = 0;

  /// Gaps between motion-filtered samples (≤ 1 s, so a pause doesn't
  /// count) and the time they cover, for [achievedImuRateHz].
  int _rateIntervals = 0;
  int _activeSpanUs = 0;
  DateTime? _lastUserSampleAt;

  double _rawAccelSumX = 0;
  double _rawAccelSumY = 0;
  double _rawAccelSumZ = 0;
  int _rawAccelSampleCount = 0;

  double _filteredAccel = 0;

  /// Low-pass weight per 50 ms sample (the original 20 Hz rate). Scaled to
  /// the real gap between samples, so moving to 50 Hz keeps the same time
  /// constant instead of making the brake/accel counter twitchier.
  static const double _alpha = 0.1;
  static const double _alphaPeriodS = 0.05;
  DateTime? _lastAccelAt;

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
  bool get crashAlertsEnabled => _crashAlertsEnabled;

  /// Motion-filtered samples per second this ride, or null before two have
  /// arrived. The OS may deliver fewer than requested; this says how many.
  /// Pauses (gaps over 1 s) are left out.
  double? get achievedImuRateHz =>
      _activeSpanUs > 0 ? _rateIntervals / (_activeSpanUs / 1e6) : null;

  /// Resolves an impact still pending when the ride stops (see
  /// ImpactDetector.flush). No-op while detection is disabled.
  void flushPendingImpact() {
    if (_impactDetectionEnabled) _impactDetector.flush();
  }

  void reset() {
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;
    _filteredAccel = 0;
    _lastAccelAt = null;
    _lastSensorEvent = null;
    _lastSensorUiPush = null;
    _brakeArmed = true;
    _accelArmed = true;
    _candidatesThisRide = 0;
    _windowsThisRide = 0;
    _rateIntervals = 0;
    _activeSpanUs = 0;
    _lastUserSampleAt = null;
    _axisCalibrator.reset();
    _estimator.reset();
    _impactDetector.reset();
    _windowRecorder.reset();
  }

  void _onCandidate(ImpactCandidate candidate) {
    if (!_impactDetectionEnabled) return;
    if (_candidatesThisRide >= maxCandidatesPerRide) return;
    _candidatesThisRide++;
    Uint8List? window;
    final wanted =
        candidate.tier >= 1 || _random.nextDouble() < tier0WindowShare;
    if (wanted && _windowsThisRide < maxWindowsPerRide) {
      window = _windowRecorder.encodeWindow(candidate.spikeAt);
      if (window != null) _windowsThisRide++;
    }
    onImpactCandidate?.call(candidate, window);
  }

  void _maybeAlert(CrashSignal? signal) {
    if (signal != null && _crashAlertsEnabled) onImpactCrash?.call(signal);
  }

  /// Feeds an accelerometer sample that *includes* gravity: the impact
  /// detector's orientation, raw-peak and free-fall checks. No-op while
  /// detection is disabled.
  void onGravityEvent(AccelerometerEvent event, {DateTime? at}) {
    if (!_impactDetectionEnabled) return;
    final now = at ?? DateTime.now();
    _windowRecorder.addRaw(now, event.x, event.y, event.z);
    _maybeAlert(
        _impactDetector.addGravitySample(now, event.x, event.y, event.z));
  }

  /// Feeds an accepted GPS fix's speed to the impact detector, which needs
  /// it to confirm a stop after an impact. No-op while detection is disabled.
  void onGpsSpeed(DateTime at, double speedMs) {
    if (!_impactDetectionEnabled) return;
    _maybeAlert(_impactDetector.addSpeed(at, speedMs));
  }

  /// Feeds gyroscope event to VehicleStateEstimator (and, while detection is
  /// on, to the impact detector and its window).
  void onGyroEvent(GyroscopeEvent event, {DateTime? at}) {
    final now = at ?? DateTime.now();
    _estimator.addGyroSample(
      timestamp: now,
      gx: event.x,
      gy: event.y,
      gz: event.z,
    );
    if (_impactDetectionEnabled) {
      _windowRecorder.addGyro(now, event.x, event.y, event.z);
      _impactDetector.addGyroSample(now, event.x, event.y, event.z);
    }
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

    final prevSample = _lastUserSampleAt;
    if (prevSample != null) {
      final gap = now.difference(prevSample).inMicroseconds;
      if (gap > 0 && gap <= 1000000) {
        _rateIntervals++;
        _activeSpanUs += gap;
      }
    }
    _lastUserSampleAt = now;

    // Raw magnitude, BEFORE the low-pass below — which would flatten a
    // 50-100 ms impact spike to a tenth of its height (§78.1).
    if (_impactDetectionEnabled) {
      _windowRecorder.addUser(now, event.x, event.y, event.z);
      _maybeAlert(_impactDetector.addSample(now, event.x, event.y, event.z));
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

    final prev = _lastAccelAt;
    _lastAccelAt = now;
    final dt = prev == null
        ? _alphaPeriodS
        : now.difference(prev).inMicroseconds / 1e6;
    final alpha =
        dt <= 0 ? 0.0 : 1 - math.pow(1 - _alpha, dt / _alphaPeriodS).toDouble();
    _filteredAccel = alpha * signedMagnitude + (1 - alpha) * _filteredAccel;

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
