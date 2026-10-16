import 'dart:math' as math;

import '../vendor/core/constants/sensor_constants.dart';
import '../vendor/core/utils/riding_score.dart';
import '../vendor/features/ride/domain/calculators/accel_axis_calibrator.dart';
import '../vendor/features/ride/domain/calculators/average_speed.dart';
import '../vendor/features/ride/domain/calculators/event_detector.dart';
import '../vendor/features/ride/domain/calculators/fix_kinematics.dart';
import '../vendor/features/ride/domain/calculators/impact_detector.dart';
import '../vendor/features/ride/domain/calculators/segment_speed_aggregator.dart';
import '../vendor/features/ride/domain/calculators/vehicle_state_estimator.dart';
import 'ride_report.dart';

/// Which leg of a hired trip the rider is on. Maya's app switches it at the
/// same moments it already knows: ride accepted → [toPickup], passenger on
/// board → [onTrip], passenger dropped → [toHome].
enum RidePhase { toPickup, onTrip, toHome }

enum SafetyEventKind {
  /// The impact detector's tier 2: a hard impact, then the bike stopped.
  crash,

  /// Stopped mid-trip for longer than [RideRecorder.unusualStopAfter].
  unusualStop,
}

class SafetyEvent {
  final SafetyEventKind kind;
  final DateTime at;
  final double? lat;
  final double? lng;

  const SafetyEvent(this.kind, this.at, this.lat, this.lng);
}

/// Records one hired trip from the phone's GPS and motion sensors.
///
/// Feed it from whatever plugins the app already uses (e.g. `geolocator`
/// at 1 Hz and `sensors_plus` at 50 Hz). It never touches a plugin itself,
/// so it runs the same on any platform and in tests.
///
/// The pipeline is ThrottleIQ's, file for file (lib/src/vendor): GPS fix
/// sanity rules, IMU axis calibration against GPS acceleration, hard
/// brake / rapid acceleration / jerk / overspeed counting with one owner per
/// count, and the tiered impact detector. The IMU half mirrors the app's
/// `SensorFusionCoordinator` (which can't be copied: it is tied to the app's
/// haptics and plugins); keep the two in step.
class RideRecorder {
  RideRecorder({
    required this.rideId,
    required this.riderRef,
    double? overspeedKmh,
    this.unusualStopAfter = const Duration(minutes: 10),
    this.crashDetection = true,
    this.onSafetyEvent,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _detector = EventDetector(
            overspeedThresholdMs:
                overspeedKmh == null ? null : overspeedKmh / 3.6),
        _impact = ImpactDetector() {
    _impact.onCandidate = _impacts.add;
  }

  /// Maya's own ids. Same rules as the API: 1-64 of `A-Z a-z 0-9 _ -`.
  final String rideId;
  final String riderRef;

  /// A stop this long during [RidePhase.onTrip] raises
  /// [SafetyEventKind.unusualStop]. Dhaka jams are long, so this only ever
  /// asks the rider "are you OK?" (see `SafetyCheck`); it never alerts alone.
  final Duration unusualStopAfter;

  /// Off: impacts are still recorded for the report, but no
  /// [SafetyEventKind.crash] is raised.
  final bool crashDetection;

  /// Called synchronously, from inside the add* call that saw the event.
  final void Function(SafetyEvent event)? onSafetyEvent;

  /// Arrival time for sensor samples fed without `at`, and for the GPS
  /// speed the impact detector pairs with them: both must share one clock,
  /// as in the app. Tests inject a fake.
  final DateTime Function() _clock;

  final EventDetector _detector;
  final ImpactDetector _impact;
  final _calibrator = AccelAxisCalibrator();
  final _estimator = VehicleStateEstimator();
  final List<ImpactCandidate> _impacts = [];
  final List<({double lat, double lng, double speedMs})> _points = [];

  RidePhase _phase = RidePhase.toPickup;
  final Map<RidePhase, double> _legM = {for (final p in RidePhase.values) p: 0};

  DateTime? _startedAt;
  DateTime? _lastFixAt;
  double? _lastLat, _lastLng;
  PrevFix? _prev;
  double _maxSpeedMs = 0;
  double _speedSum = 0;
  int _speedCount = 0;
  int _movingMs = 0;

  // IMU, as in SensorFusionCoordinator.
  double _rawSumX = 0, _rawSumY = 0, _rawSumZ = 0;
  int _rawCount = 0;
  double _filteredAccel = 0;
  DateTime? _lastAccelAt;
  DateTime? _lastSensorEvent;
  bool _brakeArmed = true;
  bool _accelArmed = true;
  static const double _alpha = 0.1;
  static const double _alphaPeriodS = 0.05;
  static const Duration _eventCooldown = Duration(seconds: 2);

  // Unusual stop: where and when the current stop began.
  DateTime? _stopSince;
  double? _stopLat, _stopLng;
  bool _stopRaised = false;
  DateTime? _lastCrashRaised;

  bool _finished = false;

  RidePhase get phase => _phase;

  /// Switch legs. Distance from now on counts toward [phase].
  set phase(RidePhase p) {
    _phase = p;
    _resetStop();
  }

  double get distanceKm => _legM.values.fold(0.0, (s, m) => s + m) / 1000;
  double legKm(RidePhase p) => _legM[p]! / 1000;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  /// Live score for the rider's screen; the server's score (which also
  /// compares her speed with the Dhaka pool) supersedes it after upload.
  int get eventScore => computeRidingScore(
        hardBrakes: _detector.hardBrakeCount,
        rapidAccel: _detector.rapidAccelCount,
        highJerk: _detector.highJerkCount,
      );

  /// One GPS fix. [at] is the fix's own timestamp.
  void addLocation({
    required double lat,
    required double lng,
    required double speedMs,
    required double accuracyM,
    required DateTime at,
    double? headingDeg,
    double? altitudeM,
  }) {
    if (_finished) return;
    if (!accuracyM.isFinite || accuracyM > SensorConstants.maxGpsAccuracyM) {
      return;
    }
    if (!lat.isFinite || !lng.isFinite) return;
    final rawSpeed = speedMs.isFinite && speedMs > 0 ? speedMs : 0.0;
    _startedAt ??= at;

    var rawDist = 0.0;
    var deltaT = 0.0;
    final prevAt = _lastFixAt;
    if (prevAt != null && _lastLat != null) {
      deltaT = at.difference(prevAt).inMilliseconds / 1000.0;
      if (deltaT <= 0) return; // out of order or duplicate
      rawDist = _haversineM(_lastLat!, _lastLng!, lat, lng);
    }
    final k = evaluateFix(
      rawSpeedMs: rawSpeed,
      prev: _prev,
      rawDistanceM: rawDist,
      deltaTSeconds: deltaT,
      accuracyM: accuracyM,
    );
    final speed = k.speedMs;

    if (speed <= SensorConstants.maxPlausibleSpeedMs && speed > _maxSpeedMs) {
      _maxSpeedMs = speed;
    }
    _speedSum += speed;
    _speedCount++;
    if (prevAt != null) {
      _movingMs += movingMsForGap(
        gapMs: at.difference(prevAt).inMilliseconds,
        prevSpeedMs: _prev?.speedMs ?? 0,
        speedMs: speed,
        distanceM: k.distanceDeltaM,
      );
    }

    _pairGpsAccel(k.acceleration);
    _maybeCrash(_impact.addSpeed(_clock(), speed), lat, lng);
    _estimator.addGpsSample(
      timestamp: at,
      lat: lat,
      lng: lng,
      speedMs: speed,
      accuracyM: accuracyM,
      headingDeg: headingDeg != null && headingDeg.isFinite ? headingDeg : null,
      altitudeM: altitudeM,
      accelerationMs2: k.acceleration,
    );
    _detector.detect(
      jerk: k.jerk,
      accel: k.acceleration,
      speedMs: speed,
      elapsedSeconds: at.difference(_startedAt!).inSeconds,
      at: at,
      detectCrash: false,
      countLongitudinal: !_calibrator.isCalibrated,
    );

    _legM[_phase] = _legM[_phase]! + k.distanceDeltaM;
    _points.add((lat: lat, lng: lng, speedMs: speed));
    _trackStop(at, lat, lng, speed);

    _prev = prevFixOf(speed, acceleration: k.acceleration, clamped: k.clamped);
    _lastFixAt = at;
    _lastLat = lat;
    _lastLng = lng;
  }

  /// Accelerometer WITHOUT gravity (sensors_plus `userAccelerometerEvents`).
  void addUserAccel(double x, double y, double z, {DateTime? at}) {
    if (_finished) return;
    final now = at ?? _clock();
    _maybeCrash(_impact.addSample(now, x, y, z), _lastLat, _lastLng);
    _estimator.addAccelSample(timestamp: now, ax: x, ay: y, az: z);
    _rawSumX += x;
    _rawSumY += y;
    _rawSumZ += z;
    _rawCount++;

    final signed = _calibrator.signedLongitudinalAccelMs2(x, y, z);
    final prev = _lastAccelAt;
    _lastAccelAt = now;
    final dt = prev == null
        ? _alphaPeriodS
        : now.difference(prev).inMicroseconds / 1e6;
    final a =
        dt <= 0 ? 0.0 : 1 - math.pow(1 - _alpha, dt / _alphaPeriodS).toDouble();
    _filteredAccel = a * signed + (1 - a) * _filteredAccel;

    // Until calibrated, the GPS path owns the counts (a pothole would read
    // as braking on an uncalibrated axis).
    if (!_calibrator.isCalibrated) return;
    if (_filteredAccel > SensorConstants.hardBrakingRearmThreshold) {
      _brakeArmed = true;
    }
    if (_filteredAccel < SensorConstants.rapidAccelRearmThreshold) {
      _accelArmed = true;
    }
    if (_lastSensorEvent != null &&
        now.difference(_lastSensorEvent!) < _eventCooldown) {
      return;
    }
    if (_brakeArmed && _filteredAccel < SensorConstants.hardBrakingThreshold) {
      _brakeArmed = false;
      _detector.hardBrakeCount++;
      _lastSensorEvent = now;
    } else if (_accelArmed &&
        _filteredAccel > SensorConstants.rapidAccelThreshold) {
      _accelArmed = false;
      _detector.rapidAccelCount++;
      _lastSensorEvent = now;
    }
  }

  /// Accelerometer WITH gravity (sensors_plus `accelerometerEvents`): the
  /// impact detector's orientation and free-fall checks.
  void addAccel(double x, double y, double z, {DateTime? at}) {
    if (_finished) return;
    _maybeCrash(
        _impact.addGravitySample(at ?? _clock(), x, y, z), _lastLat, _lastLng);
  }

  /// Gyroscope (sensors_plus `gyroscopeEvents`), rad/s.
  void addGyro(double x, double y, double z, {DateTime? at}) {
    if (_finished) return;
    final now = at ?? _clock();
    _estimator.addGyroSample(timestamp: now, gx: x, gy: y, gz: z);
    _impact.addGyroSample(now, x, y, z);
  }

  /// Ends the ride. [weatherCode] is the WMO code at the start, if the app
  /// has one (it makes the comparison with the Dhaka pool fairer in rain).
  RideReport finish({DateTime? at, int? weatherCode}) {
    if (!_finished) {
      _finished = true;
      _impact.flush();
    }
    final start = _startedAt ?? at ?? _clock();
    final end = _lastFixAt ?? at ?? start;
    return RideReport(
      rideId: rideId,
      riderRef: riderRef,
      startedAt: start,
      endedAt: end.isBefore(start) ? start : end,
      pickupKm: legKm(RidePhase.toPickup),
      tripKm: legKm(RidePhase.onTrip),
      homeKm: legKm(RidePhase.toHome),
      movingSeconds: (_movingMs / 1000).round(),
      avgSpeedKmh: _speedCount == 0 ? 0 : _speedSum / _speedCount * 3.6,
      maxSpeedKmh: _maxSpeedMs * 3.6,
      hardBrakes: _detector.hardBrakeCount,
      rapidAccels: _detector.rapidAccelCount,
      highJerks: _detector.highJerkCount,
      overspeeds: _detector.overspeedCount,
      weatherCode: weatherCode,
      segments: [
        for (final s in averageSpeedPerSegment(_points))
          if (inBangladesh(s.segmentId) && s.avgSpeedKmh <= 200) s,
      ],
      impacts: [
        for (final c in _impacts)
          if (c.tier >= 1)
            ImpactSummary(
              tier: c.tier,
              reason: c.reason.name,
              peakAccelMs2: c.peakAccelMs2,
              speedBeforeKmh: c.speedBeforeMs * 3.6,
              at: c.spikeAt,
            ),
      ],
    );
  }

  void _pairGpsAccel(double? gpsAccel) {
    if (_rawCount > 0 && gpsAccel != null) {
      _calibrator.addSample(
        ax: _rawSumX / _rawCount,
        ay: _rawSumY / _rawCount,
        az: _rawSumZ / _rawCount,
        gpsAccelMs2: gpsAccel,
      );
    }
    _rawSumX = _rawSumY = _rawSumZ = 0;
    _rawCount = 0;
  }

  /// Same gate as the app: no crash on a signal from garbage sensor data,
  /// and at most one prompt per two minutes.
  void _maybeCrash(CrashSignal? signal, double? lat, double? lng) {
    if (signal == null || !crashDetection) return;
    final confidence = _estimator.currentState?.confidence ?? 100;
    if (confidence < SensorConstants.minConfidenceForCrashAlert) return;
    final now = signal.detectedAt;
    if (_lastCrashRaised != null &&
        now.difference(_lastCrashRaised!) < const Duration(minutes: 2)) {
      return;
    }
    _lastCrashRaised = now;
    onSafetyEvent?.call(SafetyEvent(SafetyEventKind.crash, now, lat, lng));
  }

  void _trackStop(DateTime at, double lat, double lng, double speedMs) {
    if (_phase != RidePhase.onTrip) return;
    final still = speedMs < 1 &&
        (_stopLat == null || _haversineM(_stopLat!, _stopLng!, lat, lng) < 30);
    if (!still) {
      _resetStop();
      return;
    }
    if (_stopSince == null) {
      _stopSince = at;
      _stopLat = lat;
      _stopLng = lng;
    } else if (!_stopRaised && at.difference(_stopSince!) >= unusualStopAfter) {
      _stopRaised = true;
      onSafetyEvent
          ?.call(SafetyEvent(SafetyEventKind.unusualStop, at, lat, lng));
    }
  }

  void _resetStop() {
    _stopSince = null;
    _stopLat = _stopLng = null;
    _stopRaised = false;
  }
}

double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
