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
import '../../../../core/cloud/sync_manager.dart';
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
import '../../domain/calculators/final_ride_stats.dart';
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
import '../../../../core/i18n/l10n_lookup.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/analytics/analytics_service.dart';

const _uuid = Uuid();

enum RecordingStatus { idle, starting, active, paused, completed }

/// What [RideRecordingState.error] is about, when it's a blocked-recording
/// message — lets the UI offer the right fix (open Location Settings vs.
/// open the app's permission page) instead of just showing text.
enum RecordingBlockKind { none, locationServicesOff, permissionDenied }

/// [RideRecordingState.error] for "no bike to attribute the ride to". A
/// constant so the UI can recognise it and show a localized message instead
/// (see `recordingErrorText` in widgets/recording_gate.dart); the English text here is
/// what diagnostics and tests see.
const kNoBikeRecordingError = 'Please add a bike before recording a ride.';

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
  final int movingSeconds;
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
    this.movingSeconds = 0,
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
    int? movingSeconds,
    RideAlert? activeAlert,
    String? error,
    // `error`/`blockKind` are the one pair here that does NOT follow the
    // "null means keep" rule the other fields use — passing neither CLEARS
    // them. That is deliberate (an error is transient; it should not outlive
    // the state change that resolved it) but it used to be undocumented and
    // directly contradicted by the comment on `clearLiveSessionToken` below,
    // which claimed every field means "keep" (§83.10). Pass `keepError: true`
    // to carry an existing message through an unrelated update.
    bool keepError = false,
    RecordingBlockKind? blockKind,
    double? sensorAccelMs2,
    bool? crashDetected,
    int? crashCountdown,
    String? liveSessionToken,
    // `liveSessionToken: null` means "keep", like every field here EXCEPT
    // `error`/`blockKind` (see above) — this is how "Stop sharing now"
    // actually clears it.
    bool clearLiveSessionToken = false,
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
      movingSeconds: movingSeconds ?? this.movingSeconds,
      activeAlert: activeAlert ?? this.activeAlert,
      error: error ?? (keepError ? this.error : null),
      blockKind:
          blockKind ?? (keepError ? this.blockKind : RecordingBlockKind.none),
      sensorAccelMs2: sensorAccelMs2 ?? this.sensorAccelMs2,
      crashDetected: crashDetected ?? this.crashDetected,
      crashCountdown: crashCountdown ?? this.crashCountdown,
      liveSessionToken: clearLiveSessionToken
          ? null
          : (liveSessionToken ?? this.liveSessionToken),
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
    // Only ever called while SensorConstants.impactDetectorLiveEnabled.
    _sensorCoordinator.onImpactCrash = _onImpactCrash;
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
  // Gravity-including accelerometer, for ImpactDetector's orientation check.
  // Only subscribed while the impact detector is live.
  StreamSubscription<AccelerometerEvent>? _gravitySub;
  Timer? _elapsedTimer;

  /// When [RideRecordingState.activeAlert] was last set to a transient alert.
  /// Brake/accel/overspeed alerts clear after [_alertTtl] so the banner
  /// doesn't stay up for the rest of the ride (§78.3).
  DateTime? _activeAlertAt;
  static const Duration _alertTtl = Duration(seconds: 5);

  /// The signal behind the current crash alert, for the dismissal report.
  CrashSignal? _lastCrashSignal;

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

  /// Starts recording.
  ///
  /// [routeId]/[routeName] stamp the ride with the saved route being followed
  /// (issues §78.21). They're carried on the ride record rather than held in
  /// the navigation session because the session is transient — a rider who
  /// abandons guidance halfway still rode that route, and history should say
  /// so. The recorder itself does no navigation: see
  /// `navigation_session_provider.dart`.
  Future<void> startRide({
    bool userInitiated = true,
    String? bikeId,
    BikeAttributionConfidence bikeConfidence = BikeAttributionConfidence.high,
    String? routeId,
    String? routeName,
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
        error: kNoBikeRecordingError,
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
      routeId: routeId,
      routeName: routeName,
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
    _activeAlertAt = null;
    _lastCrashSignal = null;
    _persistenceCoordinator.resetCounts();
    _liveCoordinator.reset();
    _crashCoordinator.dispose();
    _lastPoint = null;
    _polyline = <LatLng>[];
    _displayStride = 1;
    _fixCount = 0;
    _skipNextDistanceDelta = false;

    unawaited(AnalyticsService.instance.log(AnalyticsEvent.rideStarted, param: AnalyticsParam.source, value: userInitiated ? 'manual' : 'auto'));
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
      unawaited(_persistenceCoordinator.persistElapsed(this.state.elapsed,
          force: true));
    }
  }

  void _startLocationStream() {
    // Notification text is fixed when the stream starts, so a snapshot of the
    // rider's language is right here — there is no widget to rebuild.
    final l10n = resolveL10n(_ref.read(appLocaleProvider));
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
            showBackgroundLocationIndicator: true,
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
                  ? l10n.recordingNotificationTextUser
                  : l10n.recordingNotificationTextAuto,
              notificationTitle:
                  _userInitiated ? l10n.rideRecordingActive : l10n.rideDetected,
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
    if (_sensorCoordinator.impactDetectionEnabled) {
      _gravitySub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(_onGravity);
    }
  }

  void _onGyro(GyroscopeEvent event) {
    if (state.status != RecordingStatus.active) return;
    _sensorCoordinator.onGyroEvent(event);
  }

  void _onGravity(AccelerometerEvent event) {
    if (state.status != RecordingStatus.active) return;
    _sensorCoordinator.onGravityEvent(event);
  }

  void _onSensor(UserAccelerometerEvent event) {
    if (state.status != RecordingStatus.active) return;
    _sensorCoordinator.onAccelEvent(
      event: event,
      detector: _detector,
      onUiPush: (filteredAccel) {
        if (mounted) {
          state = state.copyWith(sensorAccelMs2: filteredAccel);
        }
      },
      onAlertTriggered: (alert) {
        if (mounted) {
          _activeAlertAt = DateTime.now();
          state = state.copyWith(activeAlert: alert);
        }
      },
    );
  }

  /// [activeAlert] with transient alerts expired after [_alertTtl]. Fatigue
  /// is left sticky, as before: the detector re-raises it every 10 s, and
  /// expiring it would make the banner blink.
  RideAlert _alertAfterTtl(DateTime now) {
    final current = state.activeAlert;
    if (current != RideAlert.hardBraking &&
        current != RideAlert.rapidAccel &&
        current != RideAlert.overspeed) {
      return current;
    }
    final setAt = _activeAlertAt;
    if (setAt != null && now.difference(setAt) < _alertTtl) return current;
    return RideAlert.none;
  }

  /// A crash confirmed by [ImpactDetector]. Same confidence gate the GPS
  /// crash path had: don't act on a signal derived from garbage sensor data.
  void _onImpactCrash(CrashSignal signal) {
    if (!mounted || state.status != RecordingStatus.active) return;
    final confidence =
        _sensorCoordinator.estimator.currentState?.confidence ?? 100;
    if (confidence < SensorConstants.minConfidenceForCrashAlert) return;
    _lastCrashSignal = signal;
    unawaited(_onCrashDetected());
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

    final hasValidDeltaT = deltaT >= 0.1;
    final candidateDerivedSpeed = hasValidDeltaT ? distDelta / deltaT : 0.0;
    final isPlausibleDerived =
        candidateDerivedSpeed <= SensorConstants.maxPlausibleSpeedMs;
    final hasRawSpeed =
        rawSpeedMs >= SensorConstants.unreliableSpeedFallbackThresholdMs &&
            rawSpeedMs <= SensorConstants.maxPlausibleSpeedMs;

    double speedMs;
    if (hasRawSpeed) {
      if (_lastPoint != null && hasValidDeltaT) {
        final maxAllowedSpeed = _lastPoint!.speedMs +
            (SensorConstants.maxPhysicalAccelMs2 * deltaT);
        speedMs = (rawSpeedMs > maxAllowedSpeed && _lastPoint!.speedMs > 0)
            ? maxAllowedSpeed
            : rawSpeedMs;
      } else {
        speedMs = rawSpeedMs;
      }
    } else if (hasValidDeltaT &&
        isPlausibleDerived &&
        distDelta > 10.0 &&
        candidateDerivedSpeed >=
            SensorConstants.unreliableSpeedFallbackThresholdMs) {
      if (_lastPoint != null) {
        final maxAllowedSpeed = _lastPoint!.speedMs +
            (SensorConstants.maxPhysicalAccelMs2 * deltaT);
        speedMs =
            (candidateDerivedSpeed > maxAllowedSpeed && _lastPoint!.speedMs > 0)
                ? maxAllowedSpeed
                : candidateDerivedSpeed;
      } else {
        speedMs = candidateDerivedSpeed;
      }
    } else {
      speedMs = 0.0;
      distDelta = 0.0;
      accel = 0.0;
      jerk = 0.0;
    }

    if (speedMs <= SensorConstants.maxPlausibleSpeedMs && speedMs > _maxSpeed) {
      _maxSpeed = speedMs;
    }
    _speedSum += speedMs;
    _speedCount++;

    if (_lastFixTime != null) {
      final gapMs = timestamp.difference(_lastFixTime!).inMilliseconds;
      if (gapMs > 0) {
        _movingMilliseconds += movingMsForGap(
          gapMs: gapMs,
          prevSpeedMs: _lastPoint?.speedMs ?? 0,
          speedMs: speedMs,
          distanceM: distDelta,
          maxGapSeconds: _maxMovingGapSeconds,
        );
        _movingSeconds = (_movingMilliseconds / 1000).round();
      }
    }
    _lastFixTime = timestamp;

    _sensorCoordinator.pairGpsAccel(accel);
    // Wall clock, not the fix's own timestamp: the impact detector's IMU
    // samples are stamped on arrival, and the two must share one clock.
    _sensorCoordinator.onGpsSpeed(DateTime.now(), speedMs);

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

    // Crash detection is off this path (it could never fire here — §78.1);
    // it lives in ImpactDetector, behind impactDetectorLiveEnabled. Brake/
    // accel counts belong to the IMU once its axis is calibrated, and to
    // this GPS path before that — never both (§78.3).
    final alert = _detector.detect(
      jerk: jerk,
      accel: accel,
      speedMs: speedMs,
      elapsedSeconds: state.elapsed.inSeconds,
      at: timestamp,
      detectCrash: false,
      countLongitudinal: !_sensorCoordinator.axisCalibrator.isCalibrated,
    );

    if (alert != RideAlert.none && alert != state.activeAlert) {
      HapticService.alertPattern();
    }

    final RideAlert alertToShow;
    if (alert != RideAlert.none) {
      _activeAlertAt = DateTime.now();
      alertToShow = alert;
    } else {
      alertToShow = _alertAfterTtl(DateTime.now());
    }
    final here = LatLng(pos.latitude, pos.longitude);
    _appendToPolyline(here);

    state = state.copyWith(
      currentSpeedMs: speedMs,
      maxSpeedMs: _maxSpeed,
      distanceM: _totalDistance,
      movingSeconds: _movingSeconds,
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
        // Expire stale alerts here too: a stopped bike gets no GPS fixes
        // (distance filter), so _onPosition alone can't be relied on.
        state = state.copyWith(
          elapsed:
              _accumulatedDuration + DateTime.now().difference(_activeStart!),
          activeAlert: _alertAfterTtl(DateTime.now()),
          // A once-a-second tick is not the thing that resolved an error.
          keepError: true,
        );
        unawaited(_persistenceCoordinator.persistElapsed(state.elapsed));
      }
    });
  }

  Future<void> enableLiveSharing() async {
    final wasEnabled = _liveCoordinator.isLiveShareEnabled;
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
    // Only start the ticking timer once, the first time sharing turns on —
    // it reads state fresh on every tick (see startPeriodicPublishing's doc
    // comment), so it doesn't need restarting just because this was called
    // again on an already-shared ride.
    if (!wasEnabled && _liveCoordinator.isLiveShareEnabled) {
      _startLiveSessionTimer();
    }
  }

  /// "Stop sharing now" — revokes the live link without ending the ride
  /// (§78.7). See [LiveSessionCoordinator.stopSharingNow].
  Future<void> stopLiveSharing() async {
    if (state.liveSessionToken == null &&
        !_liveCoordinator.isLiveShareEnabled) {
      return;
    }
    state = state.copyWith(clearLiveSessionToken: true);
    await _liveCoordinator.stopSharingNow(
      uid: _ref.read(currentUserProvider)?.uid,
    );
  }

  /// Builds the periodic live-share publish closure, reading `state` and
  /// `_lastPoint` fresh on every tick rather than once at setup time.
  void _startLiveSessionTimer() {
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

  Future<void> pauseRide() async {
    if (state.status != RecordingStatus.active) return;
    await _persistenceCoordinator.flushPointBuffer();
    _accumulatedDuration = state.elapsed;
    _activeStart = null;
    _locationSub?.pause();
    _accelSub?.pause();
    _gyroSub?.pause();
    _gravitySub?.pause();
    state = state.copyWith(status: RecordingStatus.paused);
    // Stop the 10s live-share tick — otherwise it keeps republishing a stale
    // fix (and burning battery/network) for as long as the ride sits paused.
    // One best-effort publish lets a live viewer see "paused" instead of
    // just going quiet; not awaited since pausing must never wait on the
    // network.
    if (_liveCoordinator.isLiveShareEnabled) {
      _liveCoordinator.pausePeriodicPublishing();
      unawaited(_liveCoordinator.publishLiveSession(
        uid: _ref.read(currentUserProvider)?.uid,
        rideId: state.ride?.id,
        lastLat: _lastPoint?.lat,
        lastLng: _lastPoint?.lng,
        currentSpeedMs: state.currentSpeedMs,
        crashDetected: state.crashDetected,
        status: state.status,
      ));
    }
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
    // The first fix after a resume must not credit the paused interval as
    // moving time (it would, via movingMsForGap, if both ends were moving).
    _lastFixTime = null;
    _userInitiated = true;

    if (coldStart) {
      await WakelockPlus.enable();
      _startLocationStream();
      _startSensorStream();
      _startTimer();
      _persistenceCoordinator.startFlushTimer();
      if (_liveCoordinator.isLiveShareEnabled) {
        _startLiveSessionTimer();
      }
    } else {
      _locationSub?.resume();
      _accelSub?.resume();
      _gyroSub?.resume();
      _gravitySub?.resume();
      // Warm resume: pauseRide() suspended the live-share tick, so restart it.
      if (_liveCoordinator.isLiveShareEnabled) {
        _startLiveSessionTimer();
      }
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
    _gravitySub?.cancel();
    _locationSub = null;
    _accelSub = null;
    _gyroSub = null;
    _gravitySub = null;
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
    _gravitySub?.cancel();
    _locationSub = null;
    _accelSub = null;
    _gyroSub = null;
    _gravitySub = null;
    _elapsedTimer?.cancel();
    // Flush BEFORE dispose. dispose() fires its own unawaited flush, which
    // empties the buffer synchronously — so an awaited flush placed after it
    // found nothing to wait on, and a failed insert would re-queue the last
    // fixes into a buffer nobody reads again.
    await _persistenceCoordinator.flushPointBuffer();
    _persistenceCoordinator.dispose();
    // Same as cancelRide(): a crash countdown still running when the rider
    // taps Stop would otherwise keep ticking and dispatch an emergency alert
    // ~60 s later for a ride the rider just ended by hand.
    _crashCoordinator.dispose();
    unawaited(NotificationService.instance.cancelCrashAlert());
    WidgetsBinding.instance.removeObserver(this);

    await _tearDownLiveShare();
    await WakelockPlus.disable();
    await _persistenceCoordinator.clearRecordingState();

    final ride = state.ride!;
    await _rideDao.finalizeRide(ride.id, _buildFinalStats());
    unawaited(AnalyticsService.instance.log(AnalyticsEvent.rideEnded, param: AnalyticsParam.source, value: ride.isAuto ? 'auto' : 'manual'));

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

  /// The ride summary columns — see [buildFinalRideStats]. Shared by
  /// [stopRide] and [_onCrashDetected] (§69.O10).
  Map<String, dynamic> _buildFinalStats() => buildFinalRideStats(
        endTime: DateTime.now(),
        distanceM: _totalDistance,
        maxSpeedMs: _maxSpeed,
        speedSum: _speedSum,
        speedCount: _speedCount,
        movingMilliseconds: _movingMilliseconds,
        movingSeconds: _movingSeconds,
        durationSeconds: state.elapsed.inSeconds,
        hardBrakeCount: _detector.hardBrakeCount,
        rapidAccelCount: _detector.rapidAccelCount,
        highJerkCount: _detector.highJerkCount,
      );

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

    // Full stats, not just status + end_time: this may be the last write
    // the ride ever gets if the phone doesn't survive (§69.O10).
    await _rideDao.finalizeRide(state.ride!.id, {
      ..._buildFinalStats(),
      'status': 'crash',
    });

    await _liveCoordinator.updateLiveSessionStatus(LiveSessionStatus.crash);

    // Push it up now, while the phone still works. Best-effort: SyncManager
    // no-ops when signed out or offline, and only uploads what its unsynced
    // query selects.
    unawaited(_ref.read(syncManagerProvider).sync());
  }

  Future<void> dismissCrashAlert() async {
    await _crashCoordinator.dismissCrashAlert(
      uid: _ref.read(currentUserProvider)?.uid,
      rideId: state.ride?.id,
      lastCrashSignal: _lastCrashSignal,
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
    _gravitySub?.cancel();
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

/// The id of the signed-in rider's most recently completed ride, or null if
/// they have none. Gates the "change bike" correction on the ride summary
/// screen to only the ride just finished — see `ChangeBikeControl`.
final latestCompletedRideIdProvider = FutureProvider<String?>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;
  return RideDao().getMostRecentCompletedId(uid);
});
