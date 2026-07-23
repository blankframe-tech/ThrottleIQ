import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_point_entity.dart';
import '../../domain/calculators/motion_calculator.dart';
import '../../domain/calculators/event_detector.dart';
import '../../domain/calculators/vehicle_state_estimator.dart';
import '../../domain/calculators/recording_cadence_policy.dart';
import '../../data/models/ride_model.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/battery_service.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/rider_stats.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/data/models/bike_model.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../domain/entities/live_session_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _uuid = Uuid();

enum RecordingStatus { idle, starting, active, paused, completed }

class RideRecordingState {
  final RecordingStatus status;
  final RideEntity? ride;
  final List<LatLng> polyline;
  final double currentSpeedMs;
  final double maxSpeedMs;
  final double distanceM;
  final Duration elapsed;
  final RideAlert activeAlert;
  final String? error;
  final double sensorAccelMs2;
  final bool crashDetected;
  final int crashCountdown; // Seconds remaining (60 to 0)
  final String? liveSessionToken;

  /// 0-100, from [VehicleStateEstimator] — how much to trust the current
  /// fused motion estimate. Plumbing only in this phase; not yet surfaced
  /// in any screen.
  final int confidence;

  const RideRecordingState({
    this.status = RecordingStatus.idle,
    this.ride,
    this.polyline = const [],
    this.currentSpeedMs = 0,
    this.maxSpeedMs = 0,
    this.distanceM = 0,
    this.elapsed = Duration.zero,
    this.activeAlert = RideAlert.none,
    this.error,
    this.sensorAccelMs2 = 0,
    this.crashDetected = false,
    this.crashCountdown = 60,
    this.liveSessionToken,
    this.confidence = 0,
  });

  RideRecordingState copyWith({
    RecordingStatus? status,
    RideEntity? ride,
    List<LatLng>? polyline,
    double? currentSpeedMs,
    double? maxSpeedMs,
    double? distanceM,
    Duration? elapsed,
    RideAlert? activeAlert,
    String? error,
    double? sensorAccelMs2,
    bool? crashDetected,
    int? crashCountdown,
    String? liveSessionToken,
    int? confidence,
  }) {
    return RideRecordingState(
      status: status ?? this.status,
      ride: ride ?? this.ride,
      polyline: polyline ?? this.polyline,
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      distanceM: distanceM ?? this.distanceM,
      elapsed: elapsed ?? this.elapsed,
      activeAlert: activeAlert ?? this.activeAlert,
      error: error,
      sensorAccelMs2: sensorAccelMs2 ?? this.sensorAccelMs2,
      crashDetected: crashDetected ?? this.crashDetected,
      crashCountdown: crashCountdown ?? this.crashCountdown,
      liveSessionToken: liveSessionToken ?? this.liveSessionToken,
      confidence: confidence ?? this.confidence,
    );
  }
}

final rideRecordingProvider =
    StateNotifierProvider<RideRecordingNotifier, RideRecordingState>(
  (ref) => RideRecordingNotifier(ref),
);

class RideRecordingNotifier extends StateNotifier<RideRecordingState>
    with WidgetsBindingObserver {
  RideRecordingNotifier(this._ref) : super(const RideRecordingState());

  final Ref _ref;
  final _rideDao = RideDao();
  final _pointDao = RidePointDao();
  final _bikeDao = BikeDao();
  final _calculator = MotionCalculator();
  final _detector = EventDetector();
  final _estimator = VehicleStateEstimator();
  final _cadencePolicy = RecordingCadencePolicy();

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
  DateTime? _activeStart;
  Duration _accumulatedDuration = Duration.zero;

  // Low-pass filtered sensor acceleration (longitudinal, m/s²)
  double _filteredAccel = 0;
  static const double _alpha = 0.1; // low-pass filter coefficient

  // Cooldown to avoid multi-counting same sensor event
  DateTime? _lastSensorEvent;

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

  // Crash detection & live session
  String? _currentLiveSessionToken;
  static const Duration _liveSessionUpdateInterval = Duration(seconds: 10);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<bool> _checkLocationServices() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      state = state.copyWith(
        status: RecordingStatus.idle,
        error: 'Location services are disabled. Please enable GPS to track rides.',
      );
      return false;
    }
    return true;
  }

  Future<void> startRide() async {
    if (state.status != RecordingStatus.idle) return;
    state = state.copyWith(status: RecordingStatus.starting);

    if (!await _checkLocationServices()) return;

    final granted = await _requestPermissions();
    if (!granted) {
      state = state.copyWith(
        status: RecordingStatus.idle,
        error: 'Location permission required to track rides.',
      );
      return;
    }

    final uid = _ref.read(currentUserProvider)?.uid;
    final bike = _ref.read(activeBikeProvider);
    if (uid == null || bike == null) {
      state = state.copyWith(
        status: RecordingStatus.idle,
        error: 'Please add a bike before recording a ride.',
      );
      return;
    }

    final ride = RideEntity(
      id: _uuid.v4(),
      userId: uid,
      bikeId: bike.id,
      startTime: DateTime.now(),
    );

    await _rideDao.insert(RideModel.toMap(ride));

    _totalDistance = 0;
    _maxSpeed = 0;
    _speedSum = 0;
    _speedCount = 0;
    _accumulatedDuration = Duration.zero;
    _activeStart = DateTime.now();
    _filteredAccel = 0;
    _lastSensorEvent = null;
    _detector.reset();
    _estimator.reset();
    _cadencePolicy.reset();
    _lastPoint = null;

    state = state.copyWith(
      status: RecordingStatus.active,
      ride: ride,
      polyline: [],
      currentSpeedMs: 0,
      maxSpeedMs: 0,
      distanceM: 0,
      elapsed: Duration.zero,
      activeAlert: RideAlert.none,
    );

    await _persistRecordingState(ride);
    WidgetsBinding.instance.addObserver(this);
    await WakelockPlus.enable();
    await HapticService.rideStart();
    _startLocationStream();
    _startSensorStream();
    _startTimer();
    _startLiveSessionPublishing();
  }

  /// Forces a buffer flush the instant the app leaves the foreground
  /// (screen off, home button, task switch, or the OS about to kill it) —
  /// the app being backgrounded is exactly when an unexpected kill becomes
  /// likely, so this is the last reliable point to get already-recorded
  /// points onto disk rather than waiting on the flush timer/size to
  /// coincidentally line up first.
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
      return;
    }
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.detached ||
        appState == AppLifecycleState.hidden) {
      _flushPointBuffer();
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
  void _startLocationStream() {
    final settings = Platform.isIOS
        ? AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
          )
        : AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
            forceLocationManager: false,
            intervalDuration: const Duration(milliseconds: 500),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: 'ThrottleIQ is recording your ride in the background',
              notificationTitle: 'Ride Recording Active',
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
    // haptic alert logic below (dominant-axis low-pass filter) is untouched.
    _estimator.addAccelSample(
      timestamp: DateTime.now(),
      ax: event.x,
      ay: event.y,
      az: event.z,
    );

    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final dominantAxis = [event.x.abs(), event.y.abs(), event.z.abs()];
    final dominantIdx = dominantAxis.indexOf(dominantAxis.reduce((a, b) => a > b ? a : b));
    final signed = [event.x, event.y, event.z][dominantIdx];
    final signedMagnitude = signed < 0 ? -magnitude : magnitude;

    _filteredAccel = _alpha * signedMagnitude + (1 - _alpha) * _filteredAccel;

    if (mounted) {
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

    final speedMs = pos.speed < 0 ? 0.0 : pos.speed;
    // geolocator >=11 exposes timestamp as a non-nullable DateTime (GPS device time)
    final timestamp = pos.timestamp;

    if (pos.accuracy > SensorConstants.maxGpsAccuracyM) return;

    if (speedMs > _maxSpeed) _maxSpeed = speedMs;
    _speedSum += speedMs;
    _speedCount++;

    double? accel;
    double? jerk;
    double distDelta = 0;

    if (_lastPoint != null) {
      final result = _calculator.calculate(
        prev: _lastPoint!,
        currentSpeedMs: speedMs,
        currentLat: pos.latitude,
        currentLng: pos.longitude,
        currentTime: timestamp,
      );
      accel = result.acceleration;
      jerk = result.jerk;
      distDelta = result.distanceDeltaM;
    }

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

      if (_pointBuffer.length >= _bufferFlushSize) {
        _flushPointBuffer();
      }
    }

    final alert = _detector.detect(
      jerk: jerk,
      accel: accel,
      speedMs: speedMs,
      elapsedSeconds: state.elapsed.inSeconds,
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
    final newPolyline = [...state.polyline, LatLng(pos.latitude, pos.longitude)];
    state = state.copyWith(
      currentSpeedMs: speedMs,
      maxSpeedMs: _maxSpeed,
      distanceM: _totalDistance,
      polyline: newPolyline,
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
      }
    });

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_bufferFlushInterval, (_) {
      if (state.status == RecordingStatus.active && _pointBuffer.isNotEmpty) {
        _flushPointBuffer();
      }
    });
  }

  void _flushPointBuffer() {
    if (_pointBuffer.isEmpty) return;
    _pointDao.insertBatch(List.from(_pointBuffer));
    _pointBuffer.clear();
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
    _flushPointBuffer();
    _accumulatedDuration = state.elapsed;
    _activeStart = null;
    _locationSub?.pause();
    _accelSub?.pause();
    _gyroSub?.pause();
    state = state.copyWith(status: RecordingStatus.paused);
  }

  Future<void> resumeRide() async {
    if (state.status != RecordingStatus.paused) return;
    _activeStart = DateTime.now();
    _locationSub?.resume();
    _accelSub?.resume();
    _gyroSub?.resume();
    state = state.copyWith(status: RecordingStatus.active);
  }

  Future<String?> stopRide() async {
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
      return null;
    }

    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _elapsedTimer?.cancel();
    _flushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    _flushPointBuffer();
    await WakelockPlus.disable();
    await _clearRecordingState();

    final ride = state.ride!;
    final finalDuration = state.elapsed.inSeconds;
    final avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0.0;

    await _rideDao.finalizeRide(ride.id, {
      'end_time': DateTime.now().toIso8601String(),
      'distance_m': _totalDistance,
      'avg_speed_ms': avgSpeed,
      'max_speed_ms': _maxSpeed,
      'duration_s': finalDuration,
      'hard_brake_count': _detector.hardBrakeCount,
      'rapid_accel_count': _detector.rapidAccelCount,
      'high_jerk_count': _detector.highJerkCount,
    });

    await _bikeDao.incrementStats(ride.bikeId, _totalDistance);
    _ref.invalidate(garageProvider);
    unawaited(_updatePublicStats(ride.userId));

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

  Future<void> _persistRecordingState(RideEntity ride) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_ride_id', ride.id);
    await prefs.setString('ride_start_time', ride.startTime.toIso8601String());
  }

  Future<void> _clearRecordingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');
  }

  /// Recovers a ride left dangling by a previous app launch that never
  /// called stopRide()/dispose() — the process was killed outright (OS
  /// jetsam, an OEM battery manager, a crash) while `active_ride_id` was
  /// still set in SharedPreferences. Previously this method existed but was
  /// never called from anywhere, so a killed ride's row just sat at
  /// `status = active` forever — and RideDao.getAllForBike/getAllForUser
  /// both filter on `status = 'completed'`, so it silently never appeared
  /// in ride history at all, indistinguishable from having been lost
  /// entirely. Now wired to run once on app startup for a signed-in user
  /// (see app.dart).
  ///
  /// The in-memory running aggregates (_totalDistance, _maxSpeed, event
  /// counts) from that old session are gone — they never survive process
  /// death. Instead this recomputes real distance/avg/max speed from
  /// whatever GPS points actually made it to disk (bounded loss now — see
  /// _bufferFlushSize/_bufferFlushInterval and didChangeAppLifecycleState
  /// above), so the recovered ride is genuinely representative rather than
  /// a zeroed-out placeholder. Event counts (hard-brake/rapid-accel/high-
  /// jerk) can't be reconstructed this way and are left at 0 — a real but
  /// small and honestly-scoped limitation, documented here rather than
  /// silently guessed at.
  Future<void> recoverCrashRide() async {
    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString('active_ride_id');
    if (rideId == null) return;

    await _clearRecordingState();
    final ride = await _rideDao.getById(rideId);
    if (ride == null) return;

    final points = await _pointDao.getForRide(rideId);

    // Fewer than 2 points means there's nothing meaningful to show (no
    // distance is derivable from a single fix) — drop it rather than
    // cluttering history with a zero-everything ride.
    if (points.length < 2) {
      await _rideDao.delete(rideId);
      return;
    }

    double distanceM = 0;
    double maxSpeedMs = 0;
    double speedSum = 0;
    for (var i = 0; i < points.length; i++) {
      final speed = (points[i]['speed_ms'] as num?)?.toDouble() ?? 0;
      speedSum += speed;
      if (speed > maxSpeedMs) maxSpeedMs = speed;
      if (i > 0) {
        distanceM += _haversineMeters(
          lat1: (points[i - 1]['lat'] as num).toDouble(),
          lng1: (points[i - 1]['lng'] as num).toDouble(),
          lat2: (points[i]['lat'] as num).toDouble(),
          lng2: (points[i]['lng'] as num).toDouble(),
        );
      }
    }

    final startedAt = DateTime.parse(points.first['timestamp'] as String);
    final endedAt = DateTime.parse(points.last['timestamp'] as String);
    final durationS = endedAt.difference(startedAt).inSeconds;
    final avgSpeedMs = points.isNotEmpty ? speedSum / points.length : 0.0;

    await _rideDao.finalizeRide(rideId, {
      'end_time': endedAt.toIso8601String(),
      'distance_m': distanceM,
      'avg_speed_ms': avgSpeedMs,
      'max_speed_ms': maxSpeedMs,
      'duration_s': durationS,
    });

    final bikeId = ride['bike_id'] as String?;
    if (bikeId != null) {
      await _bikeDao.incrementStats(bikeId, distanceM);
      _ref.invalidate(garageProvider);
    }
  }

  static double _haversineMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }

  /// Handle crash detection: show countdown, play alert, notify contacts
  Future<void> _onCrashDetected() async {
    if (state.crashDetected) return; // Already handling a crash

    await HapticService.maxVibration();
    state = state.copyWith(crashDetected: true, crashCountdown: 60);

    _crashCountdownTimer?.cancel();
    _crashCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.crashCountdown > 0) {
        state = state.copyWith(crashCountdown: state.crashCountdown - 1);
      } else {
        _crashCountdownTimer?.cancel();
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
    state = state.copyWith(crashDetected: false, crashCountdown: 60);

    // Log false positive to Firestore for tuning
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid != null && state.ride != null) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('falseCrashPositives')
          .add({
        'rideId': state.ride!.id,
        'timestamp': DateTime.now().toIso8601String(),
        'crashSignal': _detector.lastCrashSignal?.toMap(),
      });
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

    // Trigger Cloud Function via Firestore write
    try {
      await _firestore.collection('crashNotifications').add({
        'uid': uid,
        'rideId': ride.id,
        'timestamp': DateTime.now().toIso8601String(),
        'lastLat': _lastPoint?.lat,
        'lastLng': _lastPoint?.lng,
        'status': 'pending', // 'pending', 'contacted', 'acknowledged'
      });
    } catch (e) {
      print('Failed to send crash notification: $e');
    }
  }

  /// Create a live share session token
  Future<String> _createLiveSessionToken() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
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
      final token = _currentLiveSessionToken ??
          await _createLiveSessionToken();
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

      await _firestore
          .collection('liveSessions')
          .doc(token)
          .set(session.toFirestore());

      if (state.liveSessionToken != token) {
        state = state.copyWith(liveSessionToken: token);
      }
    } catch (e) {
      print('Failed to publish live session: $e');
    }
  }

  /// Update live session status
  Future<void> _updateLiveSessionStatus(LiveSessionStatus status) async {
    if (_currentLiveSessionToken == null) return;

    try {
      await _firestore
          .collection('liveSessions')
          .doc(_currentLiveSessionToken)
          .update({
        'status': status.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to update live session status: $e');
    }
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
    _flushPointBuffer();
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
