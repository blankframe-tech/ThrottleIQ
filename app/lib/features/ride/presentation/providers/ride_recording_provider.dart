import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../profile/presentation/providers/speed_alert_provider.dart';
import '../../data/models/ride_model.dart';
import '../../domain/calculators/average_speed.dart';
import '../../domain/calculators/event_detector.dart';
import '../../domain/calculators/motion_calculator.dart';
import '../../domain/calculators/recording_cadence_policy.dart';
import '../../domain/calculators/ride_resume.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_point_entity.dart';
import 'helpers/crash_coordinator.dart';
import 'helpers/live_session_coordinator.dart';
import 'helpers/ride_persistence_coordinator.dart';
import 'helpers/sensor_fusion_coordinator.dart';

const _uuid = Uuid();

enum RecordingStatus { idle, starting, active, paused, completed }

/// What [RideRecordingState.error] is about, when it's a blocked-recording
/// message — lets the UI offer the right fix (open Location Settings vs.
/// open the app's permission page) instead of just showing text.
enum RecordingBlockKind { none, locationServicesOff, permissionDenied }

class RideRecordingState {
  final RecordingStatus status;
  final RideEntity? ride;

  /// Route drawn on the live map. This is a single growable list that the
  /// notifier mutates in place — it is deliberately NOT copied on each new
  /// fix (see _appendToPolyline). Because the instance is stable, a
  /// `select((s) => s.polyline)` would never see a change; watch
  /// [polylineVersion] instead. Treat as read-only outside the notifier.
  final List<LatLng> polyline;

  /// Bumped every time [polyline] is mutated, so widgets can subscribe to
  /// route changes specifically rather than to every state change.
  final int polylineVersion;

  /// Latest GPS fix, kept separately from [polyline] because the polyline is
  /// decimated for display on long rides and its last element can therefore
  /// lag the true current position.
  final LatLng? currentPosition;

  final double currentSpeedMs;
  final double maxSpeedMs;
  final double distanceM;
  final Duration elapsed;
  final RideAlert activeAlert;
  final String? error;

  /// What [error] is about, when it's non-null and came from
  /// [RideRecordingNotifier._recordingBlockedReason]. `.none` otherwise —
  /// including whenever [error] itself is null, since it clears the same way
  /// (see [copyWith]).
  final RecordingBlockKind blockKind;
  final double sensorAccelMs2;
  final bool crashDetected;
  final int crashCountdown; // Seconds remaining (60 to 0)
  final String? liveSessionToken;

  /// 0-100, from [VehicleStateEstimator] — how much to trust the current
  /// fused motion estimate.
  final int confidence;

  /// True when this paused ride was picked back up off disk at launch rather
  /// than paused by the rider in this session — see
  /// [RideRecordingNotifier.restoreInterruptedRide]. Drives the "we kept your
  /// ride" banner on the active ride screen, and clears the moment the rider
  /// resumes.
  final bool restoredFromPreviousSession;

  const RideRecordingState({
    this.status = RecordingStatus.idle,
    this.ride,
    this.polyline = const [],
    this.polylineVersion = 0,
    this.currentPosition,
    this.currentSpeedMs = 0,
    this.maxSpeedMs = 0,
    this.distanceM = 0,
    this.elapsed = Duration.zero,
    this.activeAlert = RideAlert.none,
    this.error,
    this.blockKind = RecordingBlockKind.none,
    this.sensorAccelMs2 = 0,
    this.crashDetected = false,
    this.crashCountdown = 60,
    this.liveSessionToken,
    this.confidence = 0,
    this.restoredFromPreviousSession = false,
  });

  RideRecordingState copyWith({
    RecordingStatus? status,
    RideEntity? ride,
    List<LatLng>? polyline,
    int? polylineVersion,
    LatLng? currentPosition,
    double? currentSpeedMs,
    double? maxSpeedMs,
    double? distanceM,
    Duration? elapsed,
    RideAlert? activeAlert,
    String? error,
    RecordingBlockKind? blockKind,
    double? sensorAccelMs2,
    bool? crashDetected,
    int? crashCountdown,
    String? liveSessionToken,
    int? confidence,
    bool? restoredFromPreviousSession,
  }) {
    return RideRecordingState(
      status: status ?? this.status,
      ride: ride ?? this.ride,
      polyline: polyline ?? this.polyline,
      polylineVersion: polylineVersion ?? this.polylineVersion,
      currentPosition: currentPosition ?? this.currentPosition,
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      distanceM: distanceM ?? this.distanceM,
      elapsed: elapsed ?? this.elapsed,
      activeAlert: activeAlert ?? this.activeAlert,
      error: error,
      blockKind: blockKind ?? RecordingBlockKind.none,
      sensorAccelMs2: sensorAccelMs2 ?? this.sensorAccelMs2,
      crashDetected: crashDetected ?? this.crashDetected,
      crashCountdown: crashCountdown ?? this.crashCountdown,
      liveSessionToken: liveSessionToken ?? this.liveSessionToken,
      confidence: confidence ?? this.confidence,
      restoredFromPreviousSession:
          restoredFromPreviousSession ?? this.restoredFromPreviousSession,
    );
  }
}

final rideRecordingProvider =
    StateNotifierProvider<RideRecordingNotifier, RideRecordingState>(
  (ref) => RideRecordingNotifier(ref),
);

/// Central coordinator for active ride recording.
///
/// Delegates focused responsibilities to:
/// - [LiveSessionCoordinator]: capability token creation, Firestore updates, outbox teardown
/// - [CrashCoordinator]: 60s countdown timer, notifications, emergency triggers
/// - [RidePersistenceCoordinator]: batch point buffer, SQLite persistence, interruption recovery
/// - [SensorFusionCoordinator]: IMU streams, axis calibration, complementary filtering
class RideRecordingNotifier extends StateNotifier<RideRecordingState>
    with WidgetsBindingObserver {
  RideRecordingNotifier(this._ref) : super(const RideRecordingState()) {
    NotificationService.instance.onCrashDismissed = () {
      if (state.crashDetected) unawaited(dismissCrashAlert());
    };
  }

  final Ref _ref;
  final _rideDao = RideDao();
  final _pointDao = RidePointDao();
  final _calculator = MotionCalculator();
  final _detector = EventDetector();
  final _cadencePolicy = RecordingCadencePolicy();

  // Helper coordinators
  final _liveCoordinator = LiveSessionCoordinator();
  final _crashCoordinator = CrashCoordinator();
  final _persistenceCoordinator = RidePersistenceCoordinator();
  final _sensorCoordinator = SensorFusionCoordinator();

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _elapsedTimer;

  RidePointEntity? _lastPoint;
  double _totalDistance = 0;
  double _maxSpeed = 0;
  double _speedSum = 0;
  int _speedCount = 0;

  int _movingSeconds = 0;
  int _movingMilliseconds = 0;
  DateTime? _lastFixTime;
  static const int _maxMovingGapSeconds = 60;
  DateTime? _activeStart;
  Duration _accumulatedDuration = Duration.zero;

  bool _skipNextDistanceDelta = false;

  List<LatLng> _polyline = <LatLng>[];
  static const int _maxDisplayPoints = 2000;
  int _displayStride = 1;
  int _fixCount = 0;

  bool _userInitiated = true;

  bool get isLiveShareEnabled => _liveCoordinator.isLiveShareEnabled;
  bool get isAutoStarted => !_userInitiated;

  void _appendToPolyline(LatLng p) {
    _fixCount++;
    if (_displayStride > 1 && _fixCount % _displayStride != 0) return;

    _polyline.add(p);
    if (_polyline.length < _maxDisplayPoints) return;

    var write = 1;
    for (var read = 2; read < _polyline.length; read += 2) {
      _polyline[write++] = _polyline[read];
    }
    _polyline.length = write;
    _displayStride *= 2;
  }

  Future<bool> _requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    if (perm == LocationPermission.whileInUse) {
      final bg = await Geolocator.requestPermission();
      if (bg == LocationPermission.always) {
        return true;
      }
    }

    if (Platform.isAndroid) {
      try {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (_) {}
    }

    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<({String message, RecordingBlockKind kind})?>
      _recordingBlockedReason() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (
        message: 'Location is turned off. Turn on Location Services to '
            'start a ride.',
        kind: RecordingBlockKind.locationServicesOff,
      );
    }
    if (!await _requestPermissions()) {
      return (
        message: 'ThrottleIQ needs location permission to track your ride. '
            'Grant it in Settings.',
        kind: RecordingBlockKind.permissionDenied,
      );
    }
    return null;
  }

  Future<void> startRide({
    bool userInitiated = true,
    String? bikeId,
    BikeAttributionConfidence bikeConfidence = BikeAttributionConfidence.high,
  }) async {
    if (state.status != RecordingStatus.idle) return;
    state = state.copyWith(status: RecordingStatus.starting);
    _userInitiated = userInitiated;

    final blocked = await _recordingBlockedReason();
    if (blocked != null) {
      state = state.copyWith(
        status: RecordingStatus.idle,
        error: blocked.message,
        blockKind: blocked.kind,
      );
      return;
    }

    final uid = _ref.read(currentUserProvider)?.uid;
    final resolvedBikeId = bikeId ?? _ref.read(activeBikeProvider)?.id;
    if (uid == null || resolvedBikeId == null) {
      state = state.copyWith(
        status: RecordingStatus.idle,
        error: 'Please add a bike before recording a ride.',
      );
      return;
    }

    final ride = RideEntity(
      id: _uuid.v4(),
      userId: uid,
      bikeId: resolvedBikeId,
      startTime: DateTime.now(),
      isAuto: !userInitiated,
      bikeConfidence: bikeConfidence,
    );

    await _rideDao.insert(RideModel.toMap(ride));

    _totalDistance = 0;
    _maxSpeed = 0;
    _speedSum = 0;
    _speedCount = 0;
    _movingSeconds = 0;
    _movingMilliseconds = 0;
    _lastFixTime = null;
    _accumulatedDuration = Duration.zero;
    _activeStart = DateTime.now();
    _detector.reset();
    _detector.overspeedThreshold = _ref.read(overspeedLimitProvider) / 3.6;
    _cadencePolicy.reset();
    _sensorCoordinator.reset();
    _persistenceCoordinator.resetCounts();
    _liveCoordinator.reset();
    _crashCoordinator.dispose();
    _lastPoint = null;
    _polyline = <LatLng>[];
    _displayStride = 1;
    _fixCount = 0;
    _skipNextDistanceDelta = false;

    state = state.copyWith(
      status: RecordingStatus.active,
      ride: ride,
      polyline: _polyline,
      polylineVersion: 0,
      currentSpeedMs: 0,
      maxSpeedMs: 0,
      distanceM: 0,
      elapsed: Duration.zero,
      activeAlert: RideAlert.none,
      restoredFromPreviousSession: false,
    );

    await _persistenceCoordinator.persistRecordingState(ride);
    WidgetsBinding.instance.addObserver(this);
    if (_userInitiated) {
      await WakelockPlus.enable();
    }
    await HapticService.rideStart();
    _startLocationStream();
    _startSensorStream();
    _startTimer();
    _persistenceCoordinator.startFlushTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (this.state.status != RecordingStatus.active &&
        this.state.status != RecordingStatus.paused) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistenceCoordinator.flushPointBuffer());
      unawaited(_persistenceCoordinator.persistElapsed(this.state.elapsed, force: true));
    }
  }

  void _startLocationStream() {
    final accuracy = _userInitiated
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.high;
    final distanceFilter = _userInitiated ? 3 : 10;

    final settings = Platform.isIOS
        ? AppleSettings(
            accuracy: accuracy,
            distanceFilter: distanceFilter,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
          )
        : AndroidSettings(
            accuracy: accuracy,
            distanceFilter: distanceFilter,
            forceLocationManager: false,
            intervalDuration:
                Duration(milliseconds: _userInitiated ? 500 : 2000),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationText: _userInitiated
                  ? 'ThrottleIQ is recording your ride in the background'
                  : 'ThrottleIQ detected a ride and is recording it',
              notificationTitle: _userInitiated
                  ? 'Ride Recording Active'
                  : 'Ride Detected',
              enableWakeLock: true,
            ),
          );
    _locationSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition);
  }

  void _startSensorStream() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onSensor);
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onGyro);
  }

  void _onGyro(GyroscopeEvent event) {
    if (state.status != RecordingStatus.active) return;
    _sensorCoordinator.onGyroEvent(event);
  }

  void _onSensor(UserAccelerometerEvent event) {
    if (state.status != RecordingStatus.active) return;
    _sensorCoordinator.onAccelEvent(
      event: event,
      detector: _detector,
      currentActiveAlert: state.activeAlert,
      onUiPush: (filteredAccel) {
        if (mounted) {
          state = state.copyWith(sensorAccelMs2: filteredAccel);
        }
      },
      onAlertTriggered: (alert) {
        if (mounted) {
          state = state.copyWith(activeAlert: alert);
        }
      },
    );
  }

  void _onPosition(Position pos) {
    if (state.status != RecordingStatus.active) return;

    final rawSpeedMs = pos.speed < 0 ? 0.0 : pos.speed;
    final timestamp = pos.timestamp;

    if (pos.accuracy > SensorConstants.maxGpsAccuracyM) return;

    double? accel;
    double? jerk;
    double distDelta = 0;
    double deltaT = 0;

    if (_lastPoint != null && !_skipNextDistanceDelta) {
      deltaT =
          timestamp.difference(_lastPoint!.timestamp).inMilliseconds / 1000.0;
      final result = _calculator.calculate(
        prev: _lastPoint!,
        currentSpeedMs: rawSpeedMs,
        currentLat: pos.latitude,
        currentLng: pos.longitude,
        currentTime: timestamp,
      );
      accel = result.acceleration;
      jerk = result.jerk;
      distDelta = result.distanceDeltaM;
    }
    _skipNextDistanceDelta = false;

    final derivedSpeedMs = deltaT > 0 ? distDelta / deltaT : 0.0;
    final isStationaryNoise = rawSpeedMs < 0.5 && distDelta < pos.accuracy;

    double speedMs;
    if (isStationaryNoise) {
      speedMs = 0.0;
      distDelta = 0.0;
      accel = 0.0;
      jerk = 0.0;
    } else {
      speedMs = (rawSpeedMs <
                  SensorConstants.unreliableSpeedFallbackThresholdMs &&
              derivedSpeedMs >=
                  SensorConstants.unreliableSpeedFallbackThresholdMs)
          ? derivedSpeedMs
          : rawSpeedMs;
    }

    if (speedMs > _maxSpeed) _maxSpeed = speedMs;
    _speedSum += speedMs;
    _speedCount++;

    if (_lastFixTime != null &&
        speedMs >= SensorConstants.movingSpeedThresholdMs) {
      final gapMs = timestamp.difference(_lastFixTime!).inMilliseconds;
      if (gapMs > 0 && gapMs <= _maxMovingGapSeconds * 1000) {
        _movingMilliseconds += gapMs;
        _movingSeconds = (_movingMilliseconds / 1000).round();
      }
    }
    _lastFixTime = timestamp;

    _sensorCoordinator.pairGpsAccel(accel);

    _totalDistance += distDelta;
    final periodType = speedMs < 1 ? 'idle' : 'moving';

    _sensorCoordinator.estimator.addGpsSample(
      timestamp: timestamp,
      lat: pos.latitude,
      lng: pos.longitude,
      speedMs: speedMs,
      accuracyM: pos.accuracy,
      headingDeg: pos.heading.isFinite ? pos.heading : null,
      altitudeM: pos.altitude,
      accelerationMs2: accel,
    );
    final vehicleState = _sensorCoordinator.estimator.currentState;

    final point = RidePointEntity(
      rideId: state.ride!.id,
      timestamp: timestamp,
      lat: pos.latitude,
      lng: pos.longitude,
      speedMs: speedMs,
      acceleration: accel,
      jerk: jerk,
      altitudeM: pos.altitude,
      headingDeg: vehicleState?.headingDeg,
      confidence: vehicleState?.confidence,
      imuQuality: vehicleState?.imuQuality,
      isCornering: vehicleState?.isCornering,
    );

    _lastPoint = point;

    if (_cadencePolicy.shouldPersist(
        timestamp: timestamp, vehicleState: vehicleState)) {
      _persistenceCoordinator.enqueuePoint({
        'ride_id': point.rideId,
        'timestamp': point.timestamp.toIso8601String(),
        'lat': point.lat,
        'lng': point.lng,
        'speed_ms': point.speedMs,
        'acceleration': point.acceleration,
        'jerk': point.jerk,
        'altitude_m': point.altitudeM,
        'period_type': periodType,
        'accuracy_m': pos.accuracy,
        'heading_deg': point.headingDeg,
        'confidence': point.confidence,
        'imu_quality': point.imuQuality,
        'is_cornering':
            point.isCornering == null ? null : (point.isCornering! ? 1 : 0),
      });
    }

    final alert = _detector.detect(
      jerk: jerk,
      accel: accel,
      speedMs: speedMs,
      elapsedSeconds: state.elapsed.inSeconds,
      at: timestamp,
    );

    final trustworthy = (vehicleState?.confidence ?? 100) >=
        SensorConstants.minConfidenceForCrashAlert;
    final effectiveAlert =
        (alert == RideAlert.crash && !trustworthy) ? RideAlert.none : alert;

    if (effectiveAlert == RideAlert.crash) {
      _onCrashDetected();
    } else if (effectiveAlert != RideAlert.none &&
        effectiveAlert != state.activeAlert) {
      HapticService.alertPattern();
    }

    final alertToShow =
        effectiveAlert != RideAlert.none ? effectiveAlert : state.activeAlert;
    final here = LatLng(pos.latitude, pos.longitude);
    _appendToPolyline(here);

    state = state.copyWith(
      currentSpeedMs: speedMs,
      maxSpeedMs: _maxSpeed,
      distanceM: _totalDistance,
      polyline: _polyline,
      polylineVersion: state.polylineVersion + 1,
      currentPosition: here,
      activeAlert: alertToShow,
      confidence: vehicleState?.confidence,
    );
  }

  void _startTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == RecordingStatus.active) {
        state = state.copyWith(
          elapsed:
              _accumulatedDuration + DateTime.now().difference(_activeStart!),
        );
        unawaited(_persistenceCoordinator.persistElapsed(state.elapsed));
      }
    });
  }

  Future<void> enableLiveSharing() async {
    final token = await _liveCoordinator.enableLiveSharing(
      uid: _ref.read(currentUserProvider)?.uid,
      rideId: state.ride?.id,
      lastLat: _lastPoint?.lat,
      lastLng: _lastPoint?.lng,
      currentSpeedMs: state.currentSpeedMs,
      crashDetected: state.crashDetected,
      status: state.status,
    );
    if (token != null && state.liveSessionToken != token) {
      state = state.copyWith(liveSessionToken: token);
    }
  }

  Future<void> pauseRide() async {
    if (state.status != RecordingStatus.active) return;
    await _persistenceCoordinator.flushPointBuffer();
    _accumulatedDuration = state.elapsed;
    _activeStart = null;
    _locationSub?.pause();
    _accelSub?.pause();
    _gyroSub?.pause();
    state = state.copyWith(status: RecordingStatus.paused);
    await _persistenceCoordinator.persistElapsed(state.elapsed, force: true);
  }

  Future<void> resumeRide() async {
    if (state.status != RecordingStatus.paused) return;

    final coldStart = _locationSub == null;
    if (coldStart) {
      final blocked = await _recordingBlockedReason();
      if (blocked != null) {
        state = state.copyWith(error: blocked.message, blockKind: blocked.kind);
        return;
      }
    }

    _activeStart = DateTime.now();
    _skipNextDistanceDelta = true;
    _userInitiated = true;

    if (coldStart) {
      await WakelockPlus.enable();
      _startLocationStream();
      _startSensorStream();
      _startTimer();
      _persistenceCoordinator.startFlushTimer();
      if (_liveCoordinator.isLiveShareEnabled) {
        _liveCoordinator.startPeriodicPublishing(
          onTick: () => _liveCoordinator.publishLiveSession(
            uid: _ref.read(currentUserProvider)?.uid,
            rideId: state.ride?.id,
            lastLat: _lastPoint?.lat,
            lastLng: _lastPoint?.lng,
            currentSpeedMs: state.currentSpeedMs,
            crashDetected: state.crashDetected,
            status: state.status,
          ),
        );
      }
    } else {
      _locationSub?.resume();
      _accelSub?.resume();
      _gyroSub?.resume();
    }

    state = state.copyWith(
      status: RecordingStatus.active,
      restoredFromPreviousSession: false,
    );
  }

  Future<void> cancelRide() async {
    if (state.status != RecordingStatus.active &&
        state.status != RecordingStatus.paused) {
      return;
    }
    final ride = state.ride;

    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locationSub = null;
    _accelSub = null;
    _gyroSub = null;
    _elapsedTimer?.cancel();
    _persistenceCoordinator.dispose();
    _crashCoordinator.dispose();
    await NotificationService.instance.cancelCrashAlert();
    WidgetsBinding.instance.removeObserver(this);

    await _tearDownLiveShare();
    await WakelockPlus.disable();
    await _persistenceCoordinator.clearRecordingState();
    if (ride != null) await _rideDao.delete(ride.id);

    state = const RideRecordingState();
  }

  Future<String?> stopRide() async {
    if (state.status != RecordingStatus.active &&
        state.status != RecordingStatus.paused) {
      return null;
    }

    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locationSub = null;
    _accelSub = null;
    _gyroSub = null;
    _elapsedTimer?.cancel();
    _persistenceCoordinator.dispose();
    WidgetsBinding.instance.removeObserver(this);

    await _tearDownLiveShare();
    await _persistenceCoordinator.flushPointBuffer();
    await WakelockPlus.disable();
    await _persistenceCoordinator.clearRecordingState();

    final ride = state.ride!;
    final finalDuration = state.elapsed.inSeconds;
    final derivedAvg = _movingMilliseconds > 0
        ? averageSpeedMs(
            distanceM: _totalDistance,
            movingSeconds: _movingSeconds,
            maxSpeedMs: _maxSpeed,
          )
        : (_speedCount > 0 ? _speedSum / _speedCount : 0.0);
    // Sanity check: average speed can never physically exceed max speed.
    // If anomalies occur (e.g. truncated moving time), fallback to distance/duration or maxSpeed.
    final avgSpeed = (_maxSpeed > 0 && derivedAvg > _maxSpeed)
        ? (finalDuration > 0
            ? (_totalDistance / finalDuration).clamp(0.0, _maxSpeed)
            : _maxSpeed)
        : derivedAvg;

    await _rideDao.finalizeRide(ride.id, {
      'end_time': DateTime.now().toIso8601String(),
      'distance_m': _totalDistance,
      'avg_speed_ms': avgSpeed,
      'max_speed_ms': _maxSpeed,
      'duration_s': finalDuration,
      'moving_s': _movingSeconds,
      'hard_brake_count': _detector.hardBrakeCount,
      'rapid_accel_count': _detector.rapidAccelCount,
      'high_jerk_count': _detector.highJerkCount,
    });

    final bikeDao = BikeDao();
    await bikeDao.incrementStats(ride.bikeId, _totalDistance);
    _ref.invalidate(garageProvider);
    unawaited(_persistenceCoordinator.updatePublicStats(ride.userId));
    unawaited(HomeWidgetService.instance.refreshFromLocalData());
    unawaited(_persistenceCoordinator.publishSegmentBaselines(
        ride.id, ride.startTime));

    await HapticService.rideStop();

    final rideId = ride.id;
    state = const RideRecordingState();
    return rideId;
  }

  Future<void> restoreInterruptedRide() async {
    if (state.status != RecordingStatus.idle) return;

    final rideId = await _persistenceCoordinator.getSavedActiveRideId();
    if (rideId == null) return;

    final row = await _rideDao.getById(rideId);
    if (row == null) {
      await _persistenceCoordinator.clearRecordingState();
      return;
    }

    if (row['status'] == RideStatus.completed.name) {
      await _persistenceCoordinator.clearRecordingState();
      return;
    }

    final points = await _pointDao.getForRide(rideId);
    if (points.length < 2) {
      await _rideDao.delete(rideId);
      await _persistenceCoordinator.clearRecordingState();
      return;
    }

    final fixes = <StoredFix>[
      for (final p in points)
        (
          time: DateTime.parse(p['timestamp'] as String),
          lat: (p['lat'] as num).toDouble(),
          lng: (p['lng'] as num).toDouble(),
          speedMs: (p['speed_ms'] as num?)?.toDouble() ?? 0,
        ),
    ];
    final aggregates = rebuildRideAggregates(fixes);

    _totalDistance = aggregates.distanceM;
    _maxSpeed = aggregates.maxSpeedMs;
    _speedSum = aggregates.speedSum;
    _speedCount = aggregates.speedCount;
    _movingSeconds = aggregates.movingSeconds;
    _movingMilliseconds = _movingSeconds * 1000;
    _lastFixTime = null;

    final snapshotSeconds =
        await _persistenceCoordinator.getSavedElapsedSeconds();
    _accumulatedDuration = Duration(
      seconds: snapshotSeconds ?? aggregates.span.inSeconds,
    );
    _activeStart = null;

    _sensorCoordinator.reset();
    _detector.reset();
    _detector.overspeedThreshold = _ref.read(overspeedLimitProvider) / 3.6;
    _cadencePolicy.reset();

    final last = fixes.last;
    _lastPoint = RidePointEntity(
      rideId: rideId,
      timestamp: last.time,
      lat: last.lat,
      lng: last.lng,
      speedMs: last.speedMs,
    );
    _skipNextDistanceDelta = true;

    _polyline = <LatLng>[];
    _displayStride = 1;
    _fixCount = 0;
    for (final fix in fixes) {
      _appendToPolyline(LatLng(fix.lat, fix.lng));
    }

    state = RideRecordingState(
      status: RecordingStatus.paused,
      ride: RideModel.fromMap(row),
      polyline: _polyline,
      polylineVersion: 1,
      currentPosition: _polyline.isEmpty ? null : _polyline.last,
      maxSpeedMs: _maxSpeed,
      distanceM: _totalDistance,
      elapsed: _accumulatedDuration,
      restoredFromPreviousSession: true,
    );

    WidgetsBinding.instance.addObserver(this);
    await _persistenceCoordinator.persistElapsed(state.elapsed, force: true);
    await _tearDownLiveShare();
  }

  Future<void> _onCrashDetected() async {
    if (state.crashDetected) return;
    state = state.copyWith(crashDetected: true, crashCountdown: 60);

    unawaited(_crashCoordinator.startCrashSequence(
      onTick: (secondsLeft) {
        if (mounted) state = state.copyWith(crashCountdown: secondsLeft);
      },
      onExpired: () async {
        await _crashCoordinator.dispatchEmergencyNotification(
          uid: _ref.read(currentUserProvider)?.uid,
          rideId: state.ride?.id,
          lastLat: _lastPoint?.lat,
          lastLng: _lastPoint?.lng,
        );
      },
    ));

    await _rideDao.finalizeRide(state.ride!.id, {
      'status': 'crash',
      'end_time': DateTime.now().toIso8601String(),
    });

    await _liveCoordinator.updateLiveSessionStatus(LiveSessionStatus.crash);
  }

  Future<void> dismissCrashAlert() async {
    await _crashCoordinator.dismissCrashAlert(
      uid: _ref.read(currentUserProvider)?.uid,
      rideId: state.ride?.id,
      lastCrashSignal: _detector.lastCrashSignal,
    );
    state = state.copyWith(crashDetected: false, crashCountdown: 60);

    if (state.ride != null) {
      await _rideDao.finalizeRide(state.ride!.id, {
        'status': 'active',
      });
    }

    await _liveCoordinator.updateLiveSessionStatus(LiveSessionStatus.riding);
  }

  Future<void> _tearDownLiveShare() async {
    await _liveCoordinator.tearDownLiveShare(
      uid: _ref.read(currentUserProvider)?.uid,
      outbox: _ref.read(outboxServiceProvider),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _elapsedTimer?.cancel();
    _crashCoordinator.dispose();
    _liveCoordinator.dispose();
    _persistenceCoordinator.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final rideHistoryProvider =
    FutureProvider.family<List<RideEntity>, String>((ref, bikeId) async {
  final dao = RideDao();
  final rows = await dao.getAllForBike(bikeId);
  return rows.map(RideModel.fromMap).toList();
});

final rideDetailProvider =
    FutureProvider.family<RideEntity?, String>((ref, rideId) async {
  final dao = RideDao();
  final row = await dao.getById(rideId);
  return row != null ? RideModel.fromMap(row) : null;
});
