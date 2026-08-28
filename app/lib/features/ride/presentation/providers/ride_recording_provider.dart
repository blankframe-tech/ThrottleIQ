import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/calculators/average_speed.dart';
import '../../../../core/services/home_widget_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_point_entity.dart';
import '../../domain/calculators/motion_calculator.dart';
import '../../domain/calculators/accel_axis_calibrator.dart';
import '../../domain/calculators/event_detector.dart';
import '../../domain/calculators/vehicle_state_estimator.dart';
import '../../domain/calculators/recording_cadence_policy.dart';
import '../../domain/calculators/ride_resume.dart';
import '../../data/models/ride_model.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/battery_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/rider_stats.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/data/models/bike_model.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/services/weather_service.dart';
import '../../domain/calculators/segment_speed_aggregator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  /// fused motion estimate. Plumbing only in this phase; not yet surfaced
  /// in any screen.
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

class RideRecordingNotifier extends StateNotifier<RideRecordingState>
    with WidgetsBindingObserver {
  RideRecordingNotifier(this._ref) : super(const RideRecordingState()) {
    // One cancellation path, two entry points. The rider can answer a crash
    // alert either from the in-app countdown or from the notification's
    // "I'm OK" action, and both must land on the same dismissCrashAlert() —
    // otherwise a crash dismissed from the lock screen would leave the
    // countdown running underneath and still call their emergency contacts.
    NotificationService.instance.onCrashDismissed = () {
      if (state.crashDetected) unawaited(dismissCrashAlert());
    };
  }

  final Ref _ref;
  final _rideDao = RideDao();
  final _pointDao = RidePointDao();
  final _bikeDao = BikeDao();
  final _calculator = MotionCalculator();
  final _detector = EventDetector();
  final _estimator = VehicleStateEstimator();
  final _cadencePolicy = RecordingCadencePolicy();
  final _axisCalibrator = AccelAxisCalibrator();

  // Raw accelerometer samples since the last processed GPS fix, averaged and
  // handed to _axisCalibrator alongside that fix's GPS-derived acceleration
  // — see _onPosition and accel_axis_calibrator.dart.
  double _rawAccelSumX = 0;
  double _rawAccelSumY = 0;
  double _rawAccelSumZ = 0;
  int _rawAccelSampleCount = 0;

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _elapsedTimer;
  Timer? _flushTimer;
  Timer? _crashCountdownTimer;
  Timer? _liveSessionTimer;
  RidePointEntity? _lastPoint;
  double _totalDistance = 0;
  double _maxSpeed = 0;
  double _speedSum = 0;
  int _speedCount = 0;

  /// Seconds spent above the moving threshold — the denominator of the
  /// reported average speed. See average_speed.dart for why stopped time is
  /// excluded.
  int _movingSeconds = 0;
  DateTime? _lastFixTime;

  /// Gaps longer than this (tunnel, suspended app) are not counted as moving
  /// time; mirrors `movingSeconds`'s own maxGapSeconds guard.
  static const int _maxMovingGapSeconds = 60;
  DateTime? _activeStart;
  Duration _accumulatedDuration = Duration.zero;

  /// Set whenever recording is about to continue across a break in the fix
  /// stream — a pause/resume, or a resume of a ride restored from a previous
  /// app run. Consumed by the first fix that arrives afterwards, which skips
  /// its distance/accel/jerk derivatives.
  ///
  /// Without this, [MotionCalculator] happily measures from the last fix
  /// before the break to the first one after it: park the bike, pause, drive
  /// home in a van and resume, and the ride gains the whole van journey as a
  /// single straight line. A paused ride that now survives the app being
  /// killed makes that gap arbitrarily long, so the guard stops being
  /// optional.
  bool _skipNextDistanceDelta = false;

  /// Throttles the ride-clock snapshot below — see [_persistElapsed].
  DateTime? _lastElapsedPersist;
  static const Duration _elapsedPersistInterval = Duration(seconds: 10);

  // Low-pass filtered sensor acceleration (longitudinal, m/s²)
  double _filteredAccel = 0;
  static const double _alpha = 0.1; // low-pass filter coefficient

  // Cooldown to avoid multi-counting same sensor event
  DateTime? _lastSensorEvent;

  // Rate limit for pushing the filtered accelerometer value into UI state —
  // see _onSensor.
  DateTime? _lastSensorUiPush;
  static const Duration _sensorUiPushInterval = Duration(milliseconds: 200);

  // Buffered point writes. Kept deliberately small: a phone can be killed
  // outright (OS jetsam under memory pressure, aggressive OEM battery
  // managers) with no chance to run dispose()/stopRide() — this bounds how
  // many already-recorded GPS fixes are lost with the buffer when that
  // happens. See didChangeAppLifecycleState below for the complementary
  // fix: force a flush the moment the app leaves the foreground (e.g.
  // screen off mid-ride), instead of only relying on this timer/size.
  List<Map<String, dynamic>> _pointBuffer = [];
  static const int _bufferFlushSize = 5;
  static const Duration _bufferFlushInterval = Duration(seconds: 3);

  /// Fixes that have actually reached SQLite for the current ride.
  ///
  /// Tracked (rather than queried) purely to drive [_earlyRideFlushUntil] — a
  /// count is enough, and a COUNT(*) per fix would not be.
  int _persistedPointCount = 0;

  /// Below this many persisted fixes, every fix is flushed immediately instead
  /// of batched — see the call site in `_onPosition`. Deliberately a little
  /// above the 2 that [restoreInterruptedRide] needs, so a ride killed in its
  /// opening seconds comes back with a usable trace rather than the bare
  /// minimum.
  static const int _earlyRideFlushUntil = 8;

  // ── Live map route ────────────────────────────────────────────────────
  //
  // The route used to be rebuilt as `[...state.polyline, newPoint]` on every
  // single GPS fix. With distanceFilter: 3 that is a fix every few metres, so
  // an hour of riding meant tens of thousands of whole-list copies whose cost
  // grows with the ride — O(n²) allocation, an ever-larger live set for the
  // GC to trace, and a Polyline of the same growing size handed to FlutterMap
  // to re-render each time. That is the shape of "the app quits partway
  // through a long ride but the data is fine": the OS kills the process for
  // memory/unresponsiveness while the already-flushed SQLite rows survive.
  //
  // Instead, append in place to one stable list, and cap how many points the
  // map ever holds. Persistence is entirely separate (_pointBuffer →
  // RidePointDao), so decimating here loses no recorded data — only on-screen
  // route resolution, and only on rides long enough that the extra detail is
  // sub-pixel anyway.
  List<LatLng> _polyline = <LatLng>[];
  static const int _maxDisplayPoints = 2000;
  int _displayStride = 1;
  int _fixCount = 0;

  /// Appends [p] to the display route, halving resolution whenever the cap is
  /// hit so the point count stays bounded no matter how long the ride runs.
  void _appendToPolyline(LatLng p) {
    _fixCount++;
    if (_displayStride > 1 && _fixCount % _displayStride != 0) return;

    _polyline.add(p);
    if (_polyline.length < _maxDisplayPoints) return;

    // Keep every other point (indices 0, 2, 4, …), compacting in place.
    var write = 1;
    for (var read = 2; read < _polyline.length; read += 2) {
      _polyline[write++] = _polyline[read];
    }
    _polyline.length = write;
    _displayStride *= 2;
  }

  // Crash detection & live session
  String? _currentLiveSessionToken;
  static const Duration _liveSessionUpdateInterval = Duration(seconds: 10);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WeatherService _weatherService = WeatherService();

  /// Explicit per-ride opt-in gate for live location sharing — docs/Issues.md
  /// §24.1. `_startLiveSessionPublishing()` used to run unconditionally from
  /// `startRide()`/`resumeRide()`, so EVERY ride published an unauthenticated,
  /// handle-guessable live position whether or not the rider ever meant to
  /// share it. Now [_startLiveSessionPublishing] is only ever reached through
  /// [enableLiveSharing], which the rider triggers explicitly (the "Share
  /// live location" control). Defaults to false and is reset to false at the
  /// start of every new ride and on every teardown path.
  bool _liveShareEnabled = false;

  /// Whether this ride currently has live sharing turned on. Read by the UI
  /// to decide whether "Share live location" still needs to opt in or can
  /// just re-share the existing link.
  bool get isLiveShareEnabled => _liveShareEnabled;

  /// True when the rider explicitly started this ride (slide-to-start, the
  /// home-screen widget, a group ride), false when auto-tracking started it
  /// on their behalf.
  ///
  /// Three things branch on this, and all three are about the difference
  /// between "the rider is looking at the live screen" and "the phone is in a
  /// jacket pocket":
  ///
  /// 1. **Screen wakelock.** A manual ride holds the screen on because the
  ///    rider is watching the speed readout. Holding it for a pocketed phone
  ///    burns battery and cooks the handset against the rider's leg for no
  ///    benefit. See [startRide].
  /// 2. **GPS profile.** `bestForNavigation` + `distanceFilter: 3` exists to
  ///    make the on-screen speed feel responsive (tuned against a real
  ///    "speed feels laggy" report). Nobody is reading the screen on an auto
  ///    ride, and the post-ride polyline is just as good at a lower rate —
  ///    so the auto profile trades responsiveness for battery. See
  ///    [_startLocationStream].
  /// 3. **Crash escalation.** The in-app 60-second countdown is only
  ///    dismissible from a screen the rider is looking at. An auto ride
  ///    escalates through a full-screen notification instead. See
  ///    [_onCrashDetected].
  bool _userInitiated = true;

  /// Whether the ride in progress was started by auto-tracking rather than by
  /// the rider. Read by the UI to label the ride and to explain why crash
  /// handling behaves differently.
  bool get isAutoStarted => !_userInitiated;

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

    // Android only: the foreground-service notification (see
    // _startLocationStream) keeps the process alive through normal Doze/App
    // Standby, but several OEMs (Xiaomi/MIUI, Samsung, OnePlus, etc.) run
    // their own, more aggressive background-app killers that ignore the
    // standard foreground-service exemption entirely and still kill the
    // process a while after the screen turns off. Being whitelisted from
    // battery optimization is the one thing that reliably stops that class
    // of kill. Best-effort: if the user declines, recording still works,
    // it's just more likely to be killed on aggressive OEMs.
    if (Platform.isAndroid) {
      try {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (_) {/* non-fatal — proceed without the exemption */}
    }

    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  /// Message for a GPS/permission precondition that isn't met, or null when
  /// recording is good to go.
  ///
  /// Deliberately does not touch `state`: the two callers need to fail into
  /// different states — [startRide] back to idle, [resumeRide] back to the
  /// paused ride it must not throw away — and a helper that decided that for
  /// them is what previously made "resume" and "start" have to be the same
  /// code path.
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
  /// [userInitiated] defaults to true, so every existing call site (all of
  /// which are a rider tapping something) keeps its current behaviour
  /// unchanged. Auto-tracking passes false — see [_userInitiated] for what
  /// branches on it.
  ///
  /// [bikeId] overrides the active bike. Auto-tracking passes the bike it
  /// inferred; when it can't infer one it passes null and this falls back to
  /// the active bike, in which case the caller is responsible for marking the
  /// ride's attribution confidence as low (see [BikeAttributionConfidence]).
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
    // An explicit bikeId wins over the active bike. Auto-tracking uses this
    // when it could identify the bike some other way (a paired intercom, a
    // single-bike garage); otherwise it passes null and accepts the active
    // bike with low confidence, which the rider is later asked to confirm.
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
    _lastFixTime = null;
    _accumulatedDuration = Duration.zero;
    _activeStart = DateTime.now();
    _filteredAccel = 0;
    _lastSensorEvent = null;
    _detector.reset();
    _estimator.reset();
    _cadencePolicy.reset();
    _axisCalibrator.reset();
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;
    _lastPoint = null;
    _polyline = <LatLng>[];
    _displayStride = 1;
    _fixCount = 0;
    _persistedPointCount = 0;
    _lastSensorUiPush = null;
    _skipNextDistanceDelta = false;
    _lastElapsedPersist = null;
    // A new ride never inherits the previous ride's sharing choice —
    // see docs/Issues.md §24.1.
    _liveShareEnabled = false;
    _currentLiveSessionToken = null;

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

    await _persistRecordingState(ride);
    WidgetsBinding.instance.addObserver(this);
    // Screen wakelock only for a ride the rider is actually watching. On an
    // auto-started ride the phone is pocketed, so this would hold the display
    // on against the rider's leg for the whole journey — battery cost and heat
    // for nothing anyone can see. Note this is unrelated to geolocator's
    // `enableWakeLock` in ForegroundNotificationConfig below, which is a CPU
    // partial wakelock and is needed on every ride.
    if (_userInitiated) {
      await WakelockPlus.enable();
    }
    await HapticService.rideStart();
    _startLocationStream();
    _startSensorStream();
    _startTimer();
    // Live-session publishing does NOT start here. It only ever starts via
    // enableLiveSharing(), which requires the rider to explicitly ask to
    // share this ride's location — see docs/Issues.md §24.1.
  }

  /// Forces a buffer flush the instant the app leaves the foreground
  /// (screen off, home button, task switch, or the OS about to kill it) —
  /// the app being backgrounded is exactly when an unexpected kill becomes
  /// likely, so this is the last reliable point to get already-recorded
  /// points onto disk rather than waiting on the flush timer/size to
  /// coincidentally line up first.
  ///
  /// The ride clock is snapshotted for the same reason: swiping the app out
  /// of the recents switcher goes straight to `detached` with no chance to
  /// run anything else, and elapsed time is the one part of the session that
  /// isn't derivable from the stored fixes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
      return;
    }
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.detached ||
        appState == AppLifecycleState.hidden) {
      unawaited(_flushPointBuffer());
      unawaited(_persistElapsed(force: true));
    }
  }

  // Tuned for "speed on screen feels laggy" (real-usage report): the old
  // settings (accuracy: high, distanceFilter: 5, 1s interval) meant a fix
  // only arrived after 5m of movement — fine at highway speed, but a
  // multi-second-feeling stall at parking-lot/city-traffic speeds where 5m
  // takes a while to cover. distanceFilter: 3 + bestForNavigation (which
  // requests the GPS/sensor-fusion profile actually meant for turn-by-turn
  // driving apps, not just "high accuracy") both push fixes to arrive
  // sooner. iOS previously had no platform-specific branch at all — it fell
  // back to whatever bare LocationSettings applies for AndroidSettings on a
  // non-Android platform (distanceFilter/accuracy still apply, but iOS-only
  // tuning like activityType and pauseLocationUpdatesAutomatically did
  // nothing). AppleSettings.pauseLocationUpdatesAutomatically already
  // defaults to false, but it's set explicitly here since a stale/low-
  // movement pause is exactly the kind of thing that would make speed
  // *also* look laggy, not just less precise.
  //
  // Two profiles, chosen by [_userInitiated]. Everything described above is
  // the *manual* profile and is unchanged.
  //
  // The auto profile exists because the reason for the expensive settings is
  // perceptual, not analytical: `bestForNavigation` and `distanceFilter: 3`
  // buy a live speed readout that updates without a visible stall. On an
  // auto-started ride there is no readout — the phone is in a pocket — and
  // the only consumer of the fixes is the post-ride polyline and the
  // aggregate stats, both of which are indistinguishable at 10 m spacing.
  // Dropping to `high`/10 m/2 s is the single largest battery lever available
  // to all-day tracking (see docs/AUTO_TRACKING_PLAN.md, Part 3); it is worth
  // roughly half the in-ride draw and costs nothing anyone can perceive.
  //
  // Deliberately NOT changed for the auto profile: the foreground-service
  // notification (the process must survive the same way) and, on iOS,
  // `pauseLocationUpdatesAutomatically: false` — letting iOS auto-pause an
  // unattended ride is how you silently lose the second half of it.
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
    _locationSub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  void _startSensorStream() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // ~20 Hz
    ).listen(_onSensor);
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // ~20 Hz
    ).listen(_onGyro);
  }

  // Feeds VehicleStateEstimator's heading/cornering/imuQuality pipeline.
  // Does not touch the existing haptic alert logic below.
  void _onGyro(GyroscopeEvent event) {
    if (state.status != RecordingStatus.active) return;
    _estimator.addGyroSample(
      timestamp: DateTime.now(),
      gx: event.x,
      gy: event.y,
      gz: event.z,
    );
  }

  void _onSensor(UserAccelerometerEvent event) {
    if (state.status != RecordingStatus.active) return;

    // Feeds VehicleStateEstimator's imuQuality pipeline in parallel — the
    // haptic alert logic below is untouched.
    _estimator.addAccelSample(
      timestamp: DateTime.now(),
      ax: event.x,
      ay: event.y,
      az: event.z,
    );

    // Feeds _axisCalibrator's fit for this stretch since the last GPS fix —
    // see _onPosition, which consumes and resets this average once it has a
    // GPS-derived acceleration to pair it with.
    _rawAccelSumX += event.x;
    _rawAccelSumY += event.y;
    _rawAccelSumZ += event.z;
    _rawAccelSampleCount++;

    // Signed longitudinal acceleration: a true projection onto the fitted
    // mounting axis once _axisCalibrator has enough GPS-paired samples to
    // trust, the old dominant-raw-axis guess until then — see
    // accel_axis_calibrator.dart.
    final signedMagnitude =
        _axisCalibrator.signedLongitudinalAccelMs2(event.x, event.y, event.z);

    _filteredAccel = _alpha * signedMagnitude + (1 - _alpha) * _filteredAccel;

    // The accelerometer streams at ~20 Hz, and this used to publish a new
    // state on every single sample. Every listener of the recording provider —
    // including ActiveRideScreen, which owns the FlutterMap and the whole
    // route Polyline — was therefore rebuilding 20 times a second for the sake
    // of one smoothed number. Push at ~5 Hz instead: still faster than the eye
    // resolves on a readout that is already low-pass filtered, and a 4x cut in
    // rebuild pressure over a multi-hour ride. The alert detection below still
    // sees every sample; only the UI publish is throttled.
    final nowSample = DateTime.now();
    final dueForUiPush = _lastSensorUiPush == null ||
        nowSample.difference(_lastSensorUiPush!) >= _sensorUiPushInterval;
    if (mounted && dueForUiPush) {
      _lastSensorUiPush = nowSample;
      state = state.copyWith(sensorAccelMs2: _filteredAccel);
    }

    final now = DateTime.now();
    final cooldownOk = _lastSensorEvent == null ||
        now.difference(_lastSensorEvent!).inSeconds >= 2;

    if (!cooldownOk) return;

    RideAlert? sensorAlert;
    if (_filteredAccel < SensorConstants.hardBrakingThreshold) {
      _detector.hardBrakeCount++;
      sensorAlert = RideAlert.hardBraking;
    } else if (_filteredAccel > SensorConstants.rapidAccelThreshold) {
      _detector.rapidAccelCount++;
      sensorAlert = RideAlert.rapidAccel;
    }

    if (sensorAlert != null && sensorAlert != state.activeAlert) {
      _lastSensorEvent = now;
      HapticService.alertPattern();
      if (mounted) {
        state = state.copyWith(activeAlert: sensorAlert);
      }
    }
  }

  void _onPosition(Position pos) {
    if (state.status != RecordingStatus.active) return;

    final rawSpeedMs = pos.speed < 0 ? 0.0 : pos.speed;
    // geolocator >=11 exposes timestamp as a non-nullable DateTime (GPS device time)
    final timestamp = pos.timestamp;

    if (pos.accuracy > SensorConstants.maxGpsAccuracyM) return;

    double? accel;
    double? jerk;
    double distDelta = 0;

    // The first fix after a pause/resume or a restore measures across a gap
    // of unknown length, so its derivatives describe the break rather than
    // the riding — see _skipNextDistanceDelta. The fix itself is still
    // recorded; only the deltas derived *from the previous one* are dropped.
    double deltaT = 0;
    if (_lastPoint != null && !_skipNextDistanceDelta) {
      deltaT = timestamp.difference(_lastPoint!.timestamp).inMilliseconds / 1000.0;
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

    // docs/Issues.md §49: Position.speed can read near-zero on some devices
    // (confirmed on Xcode Simulator location playback) while the rider is
    // genuinely moving. Distance/live-average-speed stay correct because
    // they're derived from GPS coordinate deltas independently of this
    // field — so when the raw speed is unreliable, fall back to that same
    // haversine-derived speed rather than recording the fix as stationary.
    final derivedSpeedMs = deltaT > 0 ? distDelta / deltaT : 0.0;
    final speedMs = (rawSpeedMs < SensorConstants.unreliableSpeedFallbackThresholdMs &&
            derivedSpeedMs >= SensorConstants.unreliableSpeedFallbackThresholdMs)
        ? derivedSpeedMs
        : rawSpeedMs;

    if (speedMs > _maxSpeed) _maxSpeed = speedMs;
    _speedSum += speedMs;
    _speedCount++;

    // Moving time, for the distance-over-moving-time average speed. Counted
    // here rather than derived at finalize so it survives the mid-ride-kill
    // recovery path, and skipped for long gaps (tunnel / app suspended)
    // whose duration we can't honestly attribute to riding.
    if (_lastFixTime != null && speedMs >= SensorConstants.movingSpeedThresholdMs) {
      final gap = timestamp.difference(_lastFixTime!).inSeconds;
      if (gap > 0 && gap <= _maxMovingGapSeconds) _movingSeconds += gap;
    }
    _lastFixTime = timestamp;

    // Pair this fix's GPS-derived acceleration with the raw accelerometer
    // samples seen since the previous fix, for _axisCalibrator's fit — see
    // accel_axis_calibrator.dart. Skipped when accel is null (no previous
    // point, or this is the first fix after a pause/resume gap the same way
    // distance/jerk are skipped above): a null accel has nothing honest to
    // pair the raw average against. The raw accumulator is cleared either
    // way so a skipped interval's samples don't bleed into the next one.
    if (accel != null && _rawAccelSampleCount > 0) {
      _axisCalibrator.addSample(
        ax: _rawAccelSumX / _rawAccelSampleCount,
        ay: _rawAccelSumY / _rawAccelSampleCount,
        az: _rawAccelSumZ / _rawAccelSampleCount,
        gpsAccelMs2: accel,
      );
    }
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;

    _totalDistance += distDelta;

    final periodType = speedMs < 1 ? 'idle' : 'moving';

    // Feed the fusion engine the same GPS+derived-accel data this point is
    // built from, then read back its fused heading/confidence/classification
    // for this tick.
    _estimator.addGpsSample(
      timestamp: timestamp,
      lat: pos.latitude,
      lng: pos.longitude,
      speedMs: speedMs,
      accuracyM: pos.accuracy,
      headingDeg: pos.heading.isFinite ? pos.heading : null,
      altitudeM: pos.altitude,
      accelerationMs2: accel,
    );
    final vehicleState = _estimator.currentState;

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

    // _lastPoint always advances to this fix regardless of whether it gets
    // persisted below — MotionCalculator's accel/jerk derivative chain needs
    // every consecutive fix, not just the thinned subset that gets written.
    _lastPoint = point;

    // Adaptive recording (Phase 1.5): thin what's WRITTEN on confident,
    // uneventful stretches — never affects _lastPoint above, the live
    // polyline below, or the ride-level distance/speed aggregates (both
    // already updated from this same fix earlier in this method).
    if (_cadencePolicy.shouldPersist(timestamp: timestamp, vehicleState: vehicleState)) {
      _pointBuffer.add({
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
        'is_cornering': point.isCornering == null ? null : (point.isCornering! ? 1 : 0),
      });

      // Early in a ride every fix is written through immediately instead of
      // being batched. A ride needs 2 persisted points to be resumable at all
      // (restoreInterruptedRide deletes anything shorter — there is no
      // distance to derive from one point), and batching means the first
      // _bufferFlushSize fixes exist only in memory. Killing the app in those
      // first seconds therefore didn't just lose a little tail, it lost the
      // whole ride. After the threshold the normal batching takes over, which
      // is what keeps a long ride from doing an SQLite write per fix.
      final flushEveryFix = _persistedPointCount < _earlyRideFlushUntil;
      if (flushEveryFix || _pointBuffer.length >= _bufferFlushSize) {
        unawaited(_flushPointBuffer());
      }
    }

    // `at:` is the fix's own GPS timestamp, not wall-clock. On the live path
    // the two are within milliseconds of each other, so this changes nothing
    // today — it exists so the identical call in the replay path
    // (AutoRideReconciler) produces identical events. See EventDetector.detect.
    final alert = _detector.detect(
      jerk: jerk,
      accel: accel,
      speedMs: speedMs,
      elapsedSeconds: state.elapsed.inSeconds,
      at: timestamp,
    );

    // Crash-alert confidence gate (Epic G follow-up): don't act on a crash
    // signal derived from garbage sensor data (e.g. mid-tunnel GPS loss).
    // Falls back to acting on the alert if the estimator hasn't produced a
    // state yet, so this can only ever suppress a would-be false positive,
    // never swallow a genuine one that already has good data behind it. A
    // suppressed crash alert is treated as no alert at all — it's dropped
    // silently rather than partially surfaced in the UI.
    final trustworthy =
        (vehicleState?.confidence ?? 100) >= SensorConstants.minConfidenceForCrashAlert;
    final effectiveAlert =
        (alert == RideAlert.crash && !trustworthy) ? RideAlert.none : alert;

    if (effectiveAlert == RideAlert.crash) {
      // Fire-and-forget: crash handling is async (UI + Firestore) and must not
      // block the position stream callback.
      _onCrashDetected();
    } else if (effectiveAlert != RideAlert.none && effectiveAlert != state.activeAlert) {
      HapticService.alertPattern();
    }

    final alertToShow = effectiveAlert != RideAlert.none ? effectiveAlert : state.activeAlert;
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
          elapsed: _accumulatedDuration + DateTime.now().difference(_activeStart!),
        );
        unawaited(_persistElapsed());
      }
    });

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_bufferFlushInterval, (_) {
      if (state.status == RecordingStatus.active && _pointBuffer.isNotEmpty) {
        unawaited(_flushPointBuffer());
      }
    });
  }

  /// Writes buffered fixes to SQLite.
  ///
  /// Now awaits the insert (it was fire-and-forget) and reports failure rather
  /// than dropping it silently. The buffer is copied and cleared *before* the
  /// await so fixes arriving mid-write aren't lost or written twice; on a
  /// failed insert they're put back at the front of the buffer so the next
  /// flush retries them rather than the ride quietly developing a hole.
  Future<void> _flushPointBuffer() async {
    if (_pointBuffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pointBuffer);
    _pointBuffer.clear();
    try {
      await _pointDao.insertBatch(batch);
      _persistedPointCount += batch.length;
    } catch (e) {
      debugPrint('[Ride] point flush failed (${batch.length} fixes): $e');
      _pointBuffer.insertAll(0, batch);
    }
  }

  /// Explicit per-ride opt-in for live location sharing (docs/Issues.md
  /// §24.1). This is the ONLY path that starts `liveSessions`/`livePointers`
  /// publishing — nothing does it automatically anymore. Call this from the
  /// rider tapping "Share live location"; a no-op if already sharing or if
  /// there's no active/paused ride to share.
  ///
  /// Awaits the first publish (rather than only kicking off the periodic
  /// timer) so `state.liveSessionToken` is populated by the time this
  /// returns — the caller needs the token immediately, to open the share
  /// sheet.
  Future<void> enableLiveSharing() async {
    if (_liveShareEnabled) return;
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
      return;
    }
    _liveShareEnabled = true;
    await _publishLiveSession();
    _startLiveSessionPublishing();
  }

  void _startLiveSessionPublishing() {
    _liveSessionTimer?.cancel();
    _liveSessionTimer = Timer.periodic(
      _liveSessionUpdateInterval,
      (_) {
        if (state.status == RecordingStatus.active ||
            state.status == RecordingStatus.paused) {
          _publishLiveSession();
        }
      },
    );
    // Publish immediately
    _publishLiveSession();
  }

  Future<void> pauseRide() async {
    if (state.status != RecordingStatus.active) return;
    await _flushPointBuffer();
    _accumulatedDuration = state.elapsed;
    _activeStart = null;
    _locationSub?.pause();
    _accelSub?.pause();
    _gyroSub?.pause();
    state = state.copyWith(status: RecordingStatus.paused);
    await _persistElapsed(force: true);
  }

  /// Picks recording back up, from either kind of pause: one the rider made
  /// in this session (subscriptions exist and are merely paused) or one that
  /// survived the app being killed (nothing is streaming — the session was
  /// rebuilt from disk by [restoreInterruptedRide]).
  ///
  /// The cold case has to re-check GPS and permissions, and must fail
  /// *without* discarding the ride: a rider who resumes with location
  /// services switched off gets an error on a still-paused ride, not a
  /// silently binned one.
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

    // Resuming is by definition a rider action — they tapped resume, so they
    // are looking at the screen. Even for a ride auto-tracking originally
    // started, that means the responsive GPS profile and the screen wakelock
    // are now the right choices. The ride row keeps its `isAuto` flag for
    // attribution and labelling; only the live sensor behaviour changes here.
    _userInitiated = true;

    if (coldStart) {
      await WakelockPlus.enable();
      _startLocationStream();
      _startSensorStream();
      _startTimer();
      // Only resume publishing if sharing was actually turned on. A cold
      // start means the process died and _liveShareEnabled — in-memory only
      // — reset to false; the rider has to re-tap "Share live location" to
      // resume broadcasting. Fail closed, not open. See docs/Issues.md §24.1.
      if (_liveShareEnabled) {
        _startLiveSessionPublishing();
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

  /// Throws the ride away: no history row, no points, nothing synced.
  ///
  /// Distinct from [stopRide] in exactly the way the rider means it — a ride
  /// started by accident, or one the app recovered that isn't worth keeping.
  /// The local row is deleted rather than marked cancelled because
  /// `RideDao.delete` also drops the ride's `ride_points`, and a ride that
  /// never reached `status = 'completed'` is invisible to every query and to
  /// the sync layer, so nothing about it ever left the device.
  Future<void> cancelRide() async {
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
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
    _flushTimer?.cancel();
    _crashCountdownTimer?.cancel();
    // A crash notification is `ongoing` and can't be swiped away, so ending
    // the ride it belongs to has to take it down explicitly or it sits on the
    // lock screen forever offering an "I'm OK" button that answers nothing.
    await NotificationService.instance.cancelCrashAlert();
    WidgetsBinding.instance.removeObserver(this);

    // Same teardown as stopRide, and queued the same way so discarding a ride
    // works offline too.
    _liveSessionTimer?.cancel();
    await _tearDownLiveShare();

    // Deliberately dropped rather than flushed — these are the points of a
    // ride that is about to be deleted.
    _pointBuffer.clear();

    await WakelockPlus.disable();
    await _clearRecordingState();
    if (ride != null) await _rideDao.delete(ride.id);

    state = const RideRecordingState();
  }

  Future<String?> stopRide() async {
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
      return null;
    }

    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locationSub = null;
    _accelSub = null;
    _gyroSub = null;
    _elapsedTimer?.cancel();
    _flushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // The live-share session was previously left running: _liveSessionTimer
    // was never cancelled here (unlike every other timer above) and the
    // session doc was never marked finished. Anyone holding the share link
    // kept seeing a permanent "RIDING" banner frozen on the last position
    // from whenever the ride ended.
    //
    // Both teardown writes now go through the outbox instead of being awaited
    // directly here. That is the fix for "I can't end a ride offline": an
    // awaited Firestore write does not fail without a connection, it simply
    // never completes, so ending a ride hung on _clearLivePointer() — which
    // runs for every rider with a uid, shared ride or not — and the rest of
    // this method (the local finalize that actually saves the ride) was never
    // reached. The outbox records the intent to disk first and bounds the
    // delivery attempt, so ending a ride is now a local operation that cannot
    // be blocked by the network. See docs/Issues.md §25.
    _liveSessionTimer?.cancel();
    await _tearDownLiveShare();

    // Awaited, not fire-and-forget: everything below this finalizes the ride
    // and hands the rider a summary, and the last few fixes must be on disk
    // before that happens or the saved distance disagrees with the trace.
    await _flushPointBuffer();
    await WakelockPlus.disable();
    await _clearRecordingState();

    final ride = state.ride!;
    final finalDuration = state.elapsed.inSeconds;
    // distance / moving time, not the mean of speed samples — see
    // average_speed.dart. Falls back to the old mean only when no moving time
    // was accumulated at all (a ride that never got above walking pace), so a
    // stationary "ride" still reports something rather than a bare zero.
    final avgSpeed = _movingSeconds > 0
        ? averageSpeedMs(distanceM: _totalDistance, movingSeconds: _movingSeconds)
        : (_speedCount > 0 ? _speedSum / _speedCount : 0.0);

    await _rideDao.finalizeRide(ride.id, {
      'end_time': DateTime.now().toIso8601String(),
      'distance_m': _totalDistance,
      'avg_speed_ms': avgSpeed,
      'max_speed_ms': _maxSpeed,
      'duration_s': finalDuration,
      // Denominator of avgSpeed above, persisted too so jam time (ride clock
      // minus this) survives past the recording session — see jam_time.dart.
      'moving_s': _movingSeconds,
      'hard_brake_count': _detector.hardBrakeCount,
      'rapid_accel_count': _detector.rapidAccelCount,
      'high_jerk_count': _detector.highJerkCount,
    });

    await _bikeDao.incrementStats(ride.bikeId, _totalDistance);
    _ref.invalidate(garageProvider);
    unawaited(_updatePublicStats(ride.userId));
    // Push the new totals to the home-screen widgets. Fire-and-forget and
    // internally no-op safe, so it can't delay or fail finishing a ride.
    unawaited(HomeWidgetService.instance.refreshFromLocalData());
    // Anonymous per-segment speed contribution for the road-baseline feature
    // — see `_publishSegmentBaselines`'s doc comment. Never blocks ending a
    // ride: a network hiccup here should never be why the summary screen is
    // slow to appear.
    unawaited(_publishSegmentBaselines(ride.id, ride.startTime));

    await HapticService.rideStop();

    final rideId = ride.id;
    state = const RideRecordingState();
    return rideId;
  }

  /// Recomputes total km/rides/earned badges from the full local ride+bike
  /// history and denormalizes them onto `users/{uid}.publicStats`, so a
  /// public/mutual-visibility profile view (UserProfileScreen) can show real
  /// stats without needing cross-user read access to the owner-only
  /// `rides`/`bikes` subcollections. Best-effort/fire-and-forget — a failure
  /// here (offline, etc.) just means the public profile shows stale numbers
  /// until the next ride, never blocks finishing the ride itself.
  Future<void> _updatePublicStats(String uid) async {
    try {
      final rideRows = await _rideDao.getAllForUser(uid);
      final bikeRows = await _bikeDao.getAllForUser(uid);
      final stats = computeRiderStats(
        rides: rideRows.map(RideModel.fromMap).toList(),
        bikes: bikeRows.map(BikeModel.fromMap).toList(),
      );
      final earnedIds = computeBadges(stats).where((b) => b.earned).map((b) => b.def.id).toList();
      await ProfileRepository().updatePublicStats(
        uid: uid,
        totalDistanceKm: stats.totalDistanceKm,
        totalRides: stats.totalRides,
        badgeIds: earnedIds,
      );
    } catch (_) {/* non-fatal — see doc comment */}
  }

  // Marker that a ride is mid-flight. Its presence at launch is what tells
  // the app a previous run ended without stopRide() ever being reached.
  static const String _prefsRideId = 'active_ride_id';
  static const String _prefsStartTime = 'ride_start_time';

  /// Last known ride clock, in seconds. Everything else about a session can
  /// be rebuilt from the stored GPS fixes (see [rebuildRideAggregates]) —
  /// elapsed time cannot, because a ride that spent forty minutes paused at
  /// a chai stall has fixes spanning far more wall-clock than it recorded.
  static const String _prefsElapsedS = 'ride_elapsed_s';

  Future<void> _persistRecordingState(RideEntity ride) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsRideId, ride.id);
    await prefs.setString(_prefsStartTime, ride.startTime.toIso8601String());
    await prefs.setInt(_prefsElapsedS, 0);
  }

  /// Snapshots the ride clock. Throttled to [_elapsedPersistInterval] on the
  /// per-second timer that calls it, since the cost of losing up to ten
  /// seconds of elapsed time to a kill is nil next to writing prefs 3,600
  /// times an hour. [force] bypasses the throttle for the moments that
  /// matter: pausing, and the app leaving the foreground.
  Future<void> _persistElapsed({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastElapsedPersist != null &&
        now.difference(_lastElapsedPersist!) < _elapsedPersistInterval) {
      return;
    }
    _lastElapsedPersist = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsElapsedS, state.elapsed.inSeconds);
  }

  Future<void> _clearRecordingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRideId);
    await prefs.remove(_prefsStartTime);
    await prefs.remove(_prefsElapsedS);
  }

  /// Picks up a ride left mid-flight by a previous app run that never reached
  /// stopRide() — the rider swiped the app out of the recents switcher, or
  /// the process was killed outright (OS jetsam, an OEM battery manager, a
  /// crash) while `active_ride_id` was still set in SharedPreferences. Runs
  /// once on app startup for a signed-in user (see app.dart).
  ///
  /// **The ride is restored, not finalized.** This used to quietly close the
  /// ride out and file it in history, which meant quitting the app mid-ride
  /// ended it: a rider who stopped for fuel and swiped the app away came
  /// back to two half-rides and no way to continue the first. Now the
  /// session is rebuilt into [RecordingStatus.paused] with its distance, top
  /// speed, moving time, route and ride clock intact, and the rider chooses
  /// what happens to it — resume, end and save, or [cancelRide] and start
  /// fresh.
  ///
  /// The in-memory aggregates from the old session are gone (they never
  /// survive process death), so they are recomputed from whatever GPS points
  /// actually made it to disk — bounded loss, see `_bufferFlushSize` /
  /// `_bufferFlushInterval` / [didChangeAppLifecycleState]. The ride clock
  /// comes from the [_prefsElapsedS] snapshot, falling back to the span of
  /// the stored fixes when none survived. Event counts (hard-brake /
  /// rapid-accel / high-jerk) cannot be reconstructed from thinned points
  /// and restart at 0 — a real, narrow limitation documented here rather
  /// than silently guessed at.
  Future<void> restoreInterruptedRide() async {
    // A ride recorded in this session already owns the notifier; a stale
    // pref must not tear it down.
    if (state.status != RecordingStatus.idle) return;

    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString(_prefsRideId);
    if (rideId == null) return;

    final row = await _rideDao.getById(rideId);
    if (row == null) {
      await _clearRecordingState();
      return;
    }

    // Already finalized — either stopRide() got as far as writing the row but
    // not as far as clearing these prefs, or crash detection closed the ride
    // out mid-recording. Either way it is in history now, and offering it
    // back as resumable would duplicate it.
    if (row['status'] == RideStatus.completed.name) {
      await _clearRecordingState();
      return;
    }

    final points = await _pointDao.getForRide(rideId);

    // Fewer than 2 fixes is not a ride worth offering back — no distance is
    // derivable from a single point. Drop it rather than presenting the
    // rider a zero-everything session to make a decision about.
    if (points.length < 2) {
      await _rideDao.delete(rideId);
      await _clearRecordingState();
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
    // Left null on purpose: the interval between the last stored fix and
    // whenever the rider resumes is not riding time, and seeding this would
    // invite _onPosition to count it as such.
    _lastFixTime = null;

    final snapshotSeconds = prefs.getInt(_prefsElapsedS);
    _accumulatedDuration = Duration(
      seconds: snapshotSeconds ?? aggregates.span.inSeconds,
    );
    _activeStart = null;

    _filteredAccel = 0;
    _lastSensorEvent = null;
    _lastSensorUiPush = null;
    _lastElapsedPersist = null;
    _detector.reset();
    _estimator.reset();
    _cadencePolicy.reset();
    // Same narrow limitation as the event counts above: the fitted axis is
    // in-memory only and doesn't survive a process death, so a resumed ride
    // re-learns it from scratch rather than picking up mid-fit.
    _axisCalibrator.reset();
    _rawAccelSumX = 0;
    _rawAccelSumY = 0;
    _rawAccelSumZ = 0;
    _rawAccelSampleCount = 0;

    // Kept so the live-share session still has a last known position to
    // publish while paused; the gap it spans is neutralised by
    // _skipNextDistanceDelta rather than by throwing the point away.
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
    // Seeded from what's actually on disk, so a short restored ride re-enters
    // the flush-every-fix window (see _earlyRideFlushUntil) — a ride the app
    // already died once during is exactly the one to be careful with.
    _persistedPointCount = fixes.length;
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

    // The ride is live again as far as the app is concerned, so it needs the
    // same background-flush hook a freshly started one gets.
    WidgetsBinding.instance.addObserver(this);
    await _persistElapsed(force: true);

    // The killed session's live-share token died with the process, so there
    // is no way to mark that `liveSessions` doc finished — but the pointer
    // that makes `/r/{username}` resolve to it is keyed by uid and very much
    // reachable. Left alone it would keep anyone with the rider's permanent
    // link parked on the last position from before the app died, for as long
    // as the paused ride sits there. Clear it now; resuming mints a fresh
    // token and re-points it (see _publishLiveSession).
    //
    // Queued, not awaited against the network: recovering an interrupted ride
    // is the one moment this must never stall, and a rider whose app died
    // mid-ride is quite likely out of coverage. Same reasoning as stopRide().
    await _tearDownLiveShare();
  }

  /// Handle crash detection: show countdown, play alert, notify contacts
  Future<void> _onCrashDetected() async {
    if (state.crashDetected) return; // Already handling a crash

    await HapticService.maxVibration();
    state = state.copyWith(crashDetected: true, crashCountdown: 60);

    // Escalate outside the app as well as inside it.
    //
    // The in-app countdown below is only answerable from a screen the rider is
    // looking at. That assumption held while every ride was started by hand,
    // and breaks completely for auto-tracking: the phone is in a jacket
    // pocket, the app is backgrounded, and the rider's only clue is a
    // vibration they will read as an ordinary notification — sixty seconds
    // before their emergency contacts are called about a crash that may never
    // have happened.
    //
    // Fired for manual rides too, not just auto-started ones. A rider who
    // pockets their phone mid-ride is in exactly the same position, and a
    // crash alert nobody can answer is the failure mode worth over-covering.
    unawaited(NotificationService.instance.showCrashAlert(secondsRemaining: 60));

    _crashCountdownTimer?.cancel();
    _crashCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.crashCountdown > 0) {
        state = state.copyWith(crashCountdown: state.crashCountdown - 1);
      } else {
        _crashCountdownTimer?.cancel();
        // The countdown is spent; the alert is no longer answerable, so it
        // must not sit on the lock screen implying it still is.
        unawaited(NotificationService.instance.cancelCrashAlert());
        _handleCrashNotification();
      }
    });

    // Update ride status to crashed
    await _rideDao.finalizeRide(state.ride!.id, {
      'status': 'crash',
      'end_time': DateTime.now().toIso8601String(),
    });

    // Update live session status
    await _updateLiveSessionStatus(LiveSessionStatus.crash);
  }

  /// User confirmed they're OK (false positive)
  Future<void> dismissCrashAlert() async {
    _crashCountdownTimer?.cancel();
    await NotificationService.instance.cancelCrashAlert();
    state = state.copyWith(crashDetected: false, crashCountdown: 60);

    // Log false positive to Firestore for tuning. Bounded and non-fatal: this
    // is telemetry, and it used to sit unguarded in front of the finalizeRide
    // below that actually gets the rider riding again.
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid != null && state.ride != null) {
      await _bestEffortWrite(
        'false-positive log',
        () => _firestore
            .collection('users')
            .doc(uid)
            .collection('falseCrashPositives')
            .add({
          'rideId': state.ride!.id,
          'timestamp': DateTime.now().toIso8601String(),
          'crashSignal': _detector.lastCrashSignal?.toMap(),
        }),
      );
    }

    // Resume normal ride status
    await _rideDao.finalizeRide(state.ride!.id, {
      'status': 'active',
    });

    await _updateLiveSessionStatus(LiveSessionStatus.riding);
  }

  /// Auto-trigger if countdown expires (no user response)
  Future<void> _handleCrashNotification() async {
    final uid = _ref.read(currentUserProvider)?.uid;
    final ride = state.ride;
    if (uid == null || ride == null) return;

    // Trigger Cloud Function via Firestore write. Bounded like every other
    // write here — but note the timeout does not discard it: the Firestore SDK
    // holds the write locally and delivers it when signal returns, which is
    // the behaviour you want for a crash alert sent from a dead spot.
    await _bestEffortWrite(
      'crash notification',
      () => _firestore.collection('crashNotifications').add({
        'uid': uid,
        'rideId': ride.id,
        'timestamp': DateTime.now().toIso8601String(),
        'lastLat': _lastPoint?.lat,
        'lastLng': _lastPoint?.lng,
        'status': 'pending', // 'pending', 'contacted', 'acknowledged'
      }),
    );
  }

  /// Create a live share session token.
  ///
  /// Must be `Random.secure()`, not the default `Random()` (docs/Issues.md
  /// §24.2). `liveSessions` is a pure capability model — this token IS the
  /// entire access control, "the link is the permission." Dart's default
  /// `Random` is a seeded 64-bit LCG initialised from the clock, so an
  /// attacker who knows roughly when a ride started can brute-force the seed
  /// and derive the token directly; the nominal 62^32 keyspace never comes
  /// into it. `Random.secure()` draws from the OS CSPRNG instead, so the
  /// token's ~190 bits of entropy are real.
  Future<String> _createLiveSessionToken() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final token = String.fromCharCodes(
      Iterable.generate(32, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return token;
  }

  /// Publish live session to Firestore
  Future<void> _publishLiveSession() async {
    final uid = _ref.read(currentUserProvider)?.uid;
    final ride = state.ride;
    if (uid == null || ride == null) return;

    try {
      final existingToken = _currentLiveSessionToken;
      final token = existingToken ?? await _createLiveSessionToken();
      _currentLiveSessionToken = token;

      final batteryLevel = await BatteryService.getBatteryLevel();

      final session = LiveSessionEntity(
        token: token,
        uid: uid,
        rideId: ride.id,
        active: true,
        lastLat: _lastPoint?.lat,
        lastLng: _lastPoint?.lng,
        speedMs: state.currentSpeedMs,
        batteryPct: batteryLevel,
        status: state.crashDetected
            ? LiveSessionStatus.crash
            : (state.status == RecordingStatus.paused
                ? LiveSessionStatus.paused
                : LiveSessionStatus.riding),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await _bestEffortWrite(
        'live session publish',
        () => _firestore
            .collection('liveSessions')
            .doc(token)
            .set(session.toFirestore()),
      );

      // Point the rider's permanent link at this session — only on the tick
      // that minted the token, not on all ~360 updates of a one-hour ride.
      // Written *after* the session doc exists so the pointer can never
      // reference a document that isn't there yet.
      if (existingToken == null) {
        await _publishLivePointer(uid, token);
      }

      if (state.liveSessionToken != token) {
        state = state.copyWith(liveSessionToken: token);
      }
    } catch (e) {
      print('Failed to publish live session: $e');
    }
  }

  /// Publishes/refreshes `livePointers/{uid}` — the one document that makes a
  /// rider's permanent share link (`/r/{username}`) work.
  ///
  /// The old `/live/{token}` link is minted fresh per ride, so a rider had to
  /// re-send it every time. The permanent link instead resolves in three
  /// *keyed* lookups, none of which is a query: `usernames/{handle}` → uid,
  /// `livePointers/{uid}` → token, `liveSessions/{token}` → the ride.
  ///
  /// Keyed by uid deliberately, NOT by username. The rule for this collection
  /// is then simply `request.auth.uid == uid` from the document path — no
  /// profile lookup, and structurally impossible for one rider to publish a
  /// pointer under another rider's name. It also survives a handle change for
  /// free, since `usernames/{handle}` is already re-pointed transactionally by
  /// ProfileRepository.setUsername.
  ///
  /// Note what this document does NOT contain: no position, no speed, no
  /// route. It is a token indirection and an on/off flag. Anyone guessing a
  /// username learns only whether that rider is out right now — and only
  /// because the rider published a shareable live session in the first place.
  ///
  /// Best-effort like every other live-share write here: a failure costs the
  /// permanent link for this ride, never the ride recording itself.
  Future<void> _publishLivePointer(String uid, String token) {
    return _bestEffortWrite(
      'live pointer publish',
      () => _firestore.collection('livePointers').doc(uid).set({
        'uid': uid,
        'token': token,
        'active': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }),
    );
  }

  /// Flips the permanent link back to "not riding right now".
  ///
  /// The token is cleared rather than left dangling: the viewer must not be
  /// able to walk from a finished pointer to a completed session doc and
  /// render its last position. `active: false` alone would be enough for the
  /// current viewer, but relying on the viewer to be well-behaved with data
  /// it has already been handed is exactly the mistake that made the
  /// liveSessions rule a privacy hole.
  /// Runs a fire-and-forget cloud write with a hard time limit.
  ///
  /// Every Firestore write in this notifier is best-effort — losing a live
  /// pointer or a crash-tuning sample must never cost the rider their ride.
  /// They were all already wrapped in `try`/`catch`, which turns out not to be
  /// enough: offline, a Firestore write neither succeeds nor throws, it just
  /// never completes, so `catch` never runs and the awaiting caller stalls
  /// indefinitely. `dismissCrashAlert()` was the worst of these — it awaited a
  /// false-positive log *before* setting the ride back to active, so
  /// dismissing a false crash alarm with no signal left the ride stuck in the
  /// crash state.
  ///
  /// Bounding the wait is what makes "best effort" actually mean best effort.
  /// Note the write is NOT cancelled on timeout — the Firestore SDK keeps it
  /// in its own local mutation queue and delivers it whenever the connection
  /// returns. We simply stop waiting. See docs/Issues.md §25.
  Future<void> _bestEffortWrite(String label, Future<void> Function() write) async {
    try {
      await write().timeout(kOutboxAttemptTimeout);
    } on TimeoutException {
      debugPrint('[Ride] $label not confirmed within '
          '${kOutboxAttemptTimeout.inSeconds}s — queued by Firestore, moving on');
    } catch (e) {
      debugPrint('[Ride] $label failed: $e');
    }
  }

  /// Contributes this ride's per-segment speeds to the anonymous shared pool
  /// `roadSpeedSamples/{segmentId}/samples` — the write side of the
  /// road-baseline feature; the read/comparison side lives in
  /// `ride_summary_screen.dart`.
  ///
  /// Segments are geohash cells (`segment_speed_aggregator.dart`), not real
  /// roads — see that file's doc comment for why. Each sample carries only
  /// `speedKmh`/`weekday`/`hour`/`weatherCode` — no uid, no rideId, no exact
  /// coordinates beyond the cell itself, enforced by `firestore.rules`'
  /// `roadSpeedSamples` rule. Weather is fetched once per ride (it doesn't
  /// meaningfully change segment-to-segment) and is best-effort — a failed
  /// fetch just means `weatherCode` is null on every sample from this ride,
  /// not a failed ride.
  ///
  /// No cap on the number of segments published — a very long ride touches
  /// more geohash cells and therefore writes more docs. Fine at beta scale;
  /// worth revisiting (batched writes, or a per-ride cap) if ride volume
  /// ever makes this collection's write cost worth watching.
  Future<void> _publishSegmentBaselines(String rideId, DateTime startTime) async {
    final rows = await _pointDao.getForRide(rideId);
    if (rows.length < 2) return; // nothing to bucket

    final segments = averageSpeedPerSegment([
      for (final r in rows)
        (lat: r['lat'] as double, lng: r['lng'] as double, speedMs: (r['speed_ms'] as num).toDouble()),
    ]);
    if (segments.isEmpty) return;

    final weather = await _weatherService.fetchForRide(
      lat: rows.first['lat'] as double,
      lng: rows.first['lng'] as double,
      at: startTime,
    );

    debugPrint('[Ride] publishing ${segments.length} road-speed sample(s)');
    for (final segment in segments) {
      await _bestEffortWrite(
        'roadSpeedSample:${segment.segmentId}',
        () => _firestore
            .collection('roadSpeedSamples')
            .doc(segment.segmentId)
            .collection('samples')
            .add({
          'speedKmh': segment.avgSpeedKmh,
          'weekday': startTime.weekday,
          'hour': startTime.hour,
          'weatherCode': weather?.weatherCode,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
    }
  }

  /// Ends the live-share session and clears the rider's permanent pointer,
  /// without ever blocking on the network.
  ///
  /// Both writes are handed to [OutboxService], which persists the intent
  /// before attempting delivery and gives that attempt a hard timeout. Offline
  /// this returns in milliseconds with the teardown durably queued; the writes
  /// land on the next sync. Online it behaves as the direct awaits used to.
  ///
  /// The local flags are cleared either way — as far as this device is
  /// concerned the ride is no longer being shared the moment the rider ends
  /// it, regardless of when the cloud finds out.
  Future<void> _tearDownLiveShare() async {
    final uid = _ref.read(currentUserProvider)?.uid;
    final token = _currentLiveSessionToken;
    _currentLiveSessionToken = null;
    _liveShareEnabled = false;
    if (uid == null) return;

    await OutboxService.instance.enqueueLiveSessionTeardown(
      uid: uid,
      token: token,
    );
  }

  /// Update live session status
  Future<void> _updateLiveSessionStatus(LiveSessionStatus status) async {
    if (_currentLiveSessionToken == null) return;

    await _bestEffortWrite(
      'live session status',
      () => _firestore
          .collection('liveSessions')
          .doc(_currentLiveSessionToken)
          .update({
        'status': status.toString().split('.').last,
        // Keep `active` consistent with `status` — a completed session that
        // still reported active: true was indistinguishable from a live one
        // to anything reading the field.
        'active': status != LiveSessionStatus.completed,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _elapsedTimer?.cancel();
    _flushTimer?.cancel();
    _crashCountdownTimer?.cancel();
    _liveSessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_flushPointBuffer());
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
