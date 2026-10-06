import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../domain/calculators/fix_kinematics.dart';
import '../../domain/calculators/motion_calculator.dart';
import '../../domain/calculators/recording_cadence_policy.dart';
import '../../domain/calculators/ride_resume.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_point_entity.dart';
import 'helpers/crash_coordinator.dart';
import 'helpers/live_session_coordinator.dart';
import 'helpers/ride_lifecycle.dart';
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

/// [RideRecordingState.error] when starting a ride threw part-way (§90.C9) —
/// a database or platform failure rather than a permission problem. Same
/// pattern as [kNoBikeRecordingError]: localized by `recordingErrorText`.
const kStartFailedRecordingError = 'Could not start the ride. Please try again.';

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

  /// True while a start/pause/resume/stop is in progress (§90.C5). The
  /// active ride screen disables Pause/Resume on it, so a double tap can't
  /// queue a second transition behind the first.
  final bool transitionPending;

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
    this.transitionPending = false,
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
    bool? transitionPending,
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
      transitionPending: transitionPending ?? this.transitionPending,
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

  /// GPS + IMU subscriptions (the gravity-including accelerometer, for
  /// ImpactDetector's orientation check, only while that detector is live).
  /// Cancelled on pause and reopened on resume — never `.pause()`d; see
  /// [RecordingSubscriptions] (§90.C1).
  final _subs = RecordingSubscriptions();

  /// Single-flight latch for start/pause/resume/stop (§90.C5).
  final _latch = TransitionLatch();

  /// Whether this process is running the ride's machinery (timers, wakelock,
  /// flush timer). False for a ride restored off disk until its first resume
  /// — that is what makes a resume "cold".
  bool _sessionLive = false;

  /// Set when the next persisted fix starts a new segment (the first fix
  /// after a resume) — stored as `segment_start = 1` so a restored ride's
  /// rebuild skips the pause gap (§90.C6).
  bool _nextFixStartsSegment = false;

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

  static const _prefsBatteryOptPrompted = 'battery_optimization_prompted';

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
      // Asked once, ever (§90.C11). It used to be re-asked on every start
      // and cold resume, so a rider who declined got the system dialog in
      // front of every single ride.
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_prefsBatteryOptPrompted) ?? false)) {
          final status = await Permission.ignoreBatteryOptimizations.status;
          if (!status.isGranted) {
            await Permission.ignoreBatteryOptimizations.request();
          }
          await prefs.setBool(_prefsBatteryOptPrompted, true);
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
    if (!_latch.tryEnter()) return;
    state = state.copyWith(status: RecordingStatus.starting);
    _userInitiated = userInitiated;
    RideEntity? inserted;

    try {
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
      inserted = ride;

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
      _nextFixStartsSegment = false;

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
      _openStreams();
      _startTimer();
      _persistenceCoordinator.startFlushTimer();
      _sessionLive = true;
    } catch (e, stack) {
      // §90.C9: a throw anywhere above used to leave status stuck at
      // `starting` — Start was then blocked until the app was restarted.
      // Undo whatever got set up and go back to idle with a reason.
      debugPrint('[RideRecording] startRide failed: $e\n$stack');
      await _subs.cancel();
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _persistenceCoordinator.dispose();
      _sessionLive = false;
      WidgetsBinding.instance.removeObserver(this);
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      try {
        await _persistenceCoordinator.clearRecordingState();
        if (inserted != null) await _rideDao.delete(inserted.id);
      } catch (_) {}
      if (mounted) {
        state = const RideRecordingState(error: kStartFailedRecordingError);
      }
    } finally {
      _latch.exit();
    }
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

  /// Opens the GPS + IMU subscriptions, replacing any already open
  /// (§90.C1/C5 — see [RecordingSubscriptions]).
  void _openStreams() {
    _subs.open(() => [
          _listenLocation(),
          ..._listenSensors(),
        ]);
  }

  StreamSubscription<Position> _listenLocation() {
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
    return Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      // A location-service error (GPS switched off mid-ride, say) used to be
      // unhandled. The ride carries on; fixes resume if the service does.
      onError: (Object e) => debugPrint('[RideRecording] position error: $e'),
    );
  }

  List<StreamSubscription<Object?>> _listenSensors() {
    void onSensorError(Object e) =>
        debugPrint('[RideRecording] sensor error: $e');
    return [
      userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(_onSensor, onError: onSensorError),
      gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(_onGyro, onError: onSensorError),
      if (_sensorCoordinator.impactDetectionEnabled)
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 50),
        ).listen(_onGravity, onError: onSensorError),
    ];
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

    double? rawAccel;
    double? rawJerk;
    double rawDist = 0;
    double deltaT = 0;

    final segmentStart = _skipNextDistanceDelta;
    final prevPoint = segmentStart ? null : _lastPoint;
    if (prevPoint != null) {
      deltaT =
          timestamp.difference(prevPoint.timestamp).inMilliseconds / 1000.0;
      final result = _calculator.calculate(
        prev: prevPoint,
        currentSpeedMs: rawSpeedMs,
        currentLat: pos.latitude,
        currentLng: pos.longitude,
        currentTime: timestamp,
      );
      rawAccel = result.acceleration;
      rawJerk = result.jerk;
      rawDist = result.distanceDeltaM;
    }
    _skipNextDistanceDelta = false;

    // Speed/distance sanity rules, shared with the auto-detection replay —
    // including the Doppler distance cap (§90.C12). See [evaluateFix].
    final k = evaluateFix(
      rawSpeedMs: rawSpeedMs,
      prev: prevPoint == null ? null : (speedMs: prevPoint.speedMs),
      rawDistanceM: rawDist,
      deltaTSeconds: deltaT,
      accuracyM: pos.accuracy,
      acceleration: rawAccel,
      jerk: rawJerk,
    );
    final speedMs = k.speedMs;
    final distDelta = k.distanceDeltaM;
    final accel = k.acceleration;
    final jerk = k.jerk;

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

    // The first fix after a resume is always persisted, marked as starting
    // a segment, so a restore never bridges the pause gap (§90.C6). The
    // cadence policy is still consulted so its own clock advances.
    final cadenceSays = _cadencePolicy.shouldPersist(
        timestamp: timestamp, vehicleState: vehicleState);
    final markSegment = _nextFixStartsSegment;
    if (cadenceSays || markSegment) {
      _nextFixStartsSegment = false;
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
        if (markSegment) 'segment_start': 1,
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
    if (!_latch.tryEnter()) return;
    state = state.copyWith(transitionPending: true, keepError: true);
    try {
      // Cancel, not `.pause()` (§90.C1): a paused broadcast subscription
      // buffers every fix and IMU sample and replays them all on resume, so
      // whatever the bike did while paused (a van ride) was counted. The
      // status flip comes first so nothing arriving mid-cancel is processed.
      _accumulatedDuration = state.elapsed;
      _activeStart = null;
      state = state.copyWith(status: RecordingStatus.paused, keepError: true);
      await _subs.cancel();
      await _persistenceCoordinator.flushPointBuffer();
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
    } finally {
      _latch.exit();
      if (mounted) {
        state = state.copyWith(transitionPending: false, keepError: true);
      }
    }
  }

  Future<void> resumeRide() async {
    if (state.status != RecordingStatus.paused) return;
    // Claimed synchronously, before the first await (§90.C5): two taps
    // landing together both used to pass the status check and each open a
    // full set of subscriptions.
    if (!_latch.tryEnter()) return;
    state = state.copyWith(transitionPending: true, keepError: true);

    try {
      final coldStart = !_sessionLive;
      if (coldStart) {
        final blocked = await _recordingBlockedReason();
        if (blocked != null) {
          state =
              state.copyWith(error: blocked.message, blockKind: blocked.kind);
          return;
        }
      }
      if (!mounted || state.status != RecordingStatus.paused) return;

      _activeStart = DateTime.now();
      _skipNextDistanceDelta = true;
      _nextFixStartsSegment = true;
      // The first fix after a resume must not credit the paused interval as
      // moving time (it would, via movingMsForGap, if both ends were moving).
      _lastFixTime = null;
      _userInitiated = true;

      if (coldStart) {
        await WakelockPlus.enable();
        _startTimer();
        _persistenceCoordinator.startFlushTimer();
        _sessionLive = true;
      }
      // Status first, then a fresh subscription set: a new subscription on a
      // broadcast stream sees only what happens from now on (§90.C1).
      state = state.copyWith(
        status: RecordingStatus.active,
        restoredFromPreviousSession: false,
      );
      _openStreams();
      // pauseRide() suspended the live-share tick (or this is a cold resume
      // with sharing on), so restart it.
      if (_liveCoordinator.isLiveShareEnabled) {
        _startLiveSessionTimer();
      }
    } finally {
      _latch.exit();
      if (mounted) {
        state = state.copyWith(transitionPending: false, keepError: true);
      }
    }
  }

  /// Stops the recording machinery: subscriptions, timers, observers.
  /// Shared by [cancelRide] and [stopRide].
  Future<void> _stopMachinery() async {
    await _subs.cancel();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _sessionLive = false;
  }

  Future<void> cancelRide() async {
    if (state.status != RecordingStatus.active &&
        state.status != RecordingStatus.paused) {
      return;
    }
    if (!await _latch.enterWhenFree()) return;
    // The transition we waited on may have ended the ride already.
    if (state.status != RecordingStatus.active &&
        state.status != RecordingStatus.paused) {
      _latch.exit();
      return;
    }
    try {
      final ride = state.ride;

      await _stopMachinery();
      _persistenceCoordinator.dispose();
      _crashCoordinator.dispose();
      await NotificationService.instance.cancelCrashAlert();
      WidgetsBinding.instance.removeObserver(this);

      await _tearDownLiveShare();
      await WakelockPlus.disable();
      // Tombstoned, not just deleted (§90.C10): a crash ride is uploaded the
      // moment crash detection fires, so a discarded one would otherwise be
      // pulled straight back down by the next sync.
      if (ride != null) {
        await _rideDao.deleteWithTombstone(ride.id, userId: ride.userId);
      }
      // Marker last: if the delete throws, the next launch still finds the
      // ride and offers it back rather than leaving an orphan `active` row.
      await _persistenceCoordinator.clearRecordingState();

      state = const RideRecordingState();
    } finally {
      _latch.exit();
    }
  }

  Future<String?> stopRide() async {
    if (state.status != RecordingStatus.active &&
        state.status != RecordingStatus.paused) {
      return null;
    }
    if (!await _latch.enterWhenFree()) return null;
    if (state.status != RecordingStatus.active &&
        state.status != RecordingStatus.paused) {
      _latch.exit();
      return null;
    }
    state = state.copyWith(transitionPending: true, keepError: true);

    final ride = state.ride!;
    var finalized = false;
    try {
      await _stopMachinery();
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

      // §90.C8: finalize first, recovery marker last. The marker used to be
      // cleared before the row was finalized, so a kill in between left the
      // ride `active` forever — out of history, never synced, unrecoverable.
      final finalStats = _buildFinalStats();
      await runStopSequence(
        finalize: () async {
          await _rideDao.finalizeRide(ride.id, finalStats);
          finalized = true;
        },
        afterFinalize: () async {
          unawaited(AnalyticsService.instance.log(AnalyticsEvent.rideEnded,
              param: AnalyticsParam.source,
              value: ride.isAuto ? 'auto' : 'manual'));
          await BikeDao().incrementStats(ride.bikeId, _totalDistance);
        },
        clearMarker: _persistenceCoordinator.clearRecordingState,
      );
    } catch (e, stack) {
      debugPrint('[RideRecording] stopRide failed: $e\n$stack');
      if (!finalized) {
        // Finalizing failed: the marker is still set (see runStopSequence),
        // so the next launch restores this ride rather than losing it.
        _latch.exit();
        if (mounted) state = const RideRecordingState();
        return null;
      }
      // Finalized, but a post-finalize step (odometer) failed — the ride
      // itself is safe and complete, so carry on to the summary.
    }

    try {
      _ref.invalidate(garageProvider);
      unawaited(_persistenceCoordinator.updatePublicStats(ride.userId));
      unawaited(HomeWidgetService.instance.refreshFromLocalData());
      unawaited(_persistenceCoordinator.publishSegmentBaselines(
          ride.id, ride.startTime));

      await HapticService.rideStop();
    } finally {
      _latch.exit();
      if (mounted) state = const RideRecordingState();
    }
    return ride.id;
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
      // Tombstoned: a `crash` row may already have been uploaded (§90.C10).
      await _rideDao.deleteWithTombstone(rideId,
          userId: row['user_id'] as String?);
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
    // Pause gaps are skipped via the persisted segment markers (§90.C6).
    final aggregates = rebuildRideAggregates(
      fixes,
      segmentStartIndices: {
        for (var i = 0; i < points.length; i++)
          if ((points[i]['segment_start'] as num?) == 1) i,
      },
    );

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
    _nextFixStartsSegment = true;
    _sessionLive = false;

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
    unawaited(_subs.cancel());
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
