import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_point_entity.dart';
import '../../domain/calculators/motion_calculator.dart';
import '../../domain/calculators/event_detector.dart';
import '../../data/models/ride_model.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';

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
    );
  }
}

final rideRecordingProvider =
    StateNotifierProvider<RideRecordingNotifier, RideRecordingState>(
  (ref) => RideRecordingNotifier(ref),
);

class RideRecordingNotifier extends StateNotifier<RideRecordingState> {
  RideRecordingNotifier(this._ref) : super(const RideRecordingState());

  final Ref _ref;
  final _rideDao = RideDao();
  final _pointDao = RidePointDao();
  final _bikeDao = BikeDao();
  final _calculator = MotionCalculator();
  final _detector = EventDetector();

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _elapsedTimer;
  Timer? _flushTimer;
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

  // Buffered point writes
  List<Map<String, dynamic>> _pointBuffer = [];
  static const int _bufferFlushSize = 20;
  static const Duration _bufferFlushInterval = Duration(seconds: 10);

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
    await WakelockPlus.enable();
    await HapticService.rideStart();
    _startLocationStream();
    _startSensorStream();
    _startTimer();
  }

  void _startLocationStream() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'ThrottleIQ is recording your ride in the background',
          notificationTitle: 'Ride Recording Active',
          enableWakeLock: true,
        ),
      ),
    ).listen(_onPosition);
  }

  void _startSensorStream() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // ~20 Hz
    ).listen(_onSensor);
  }

  void _onSensor(UserAccelerometerEvent event) {
    if (state.status != RecordingStatus.active) return;

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
    final timestamp = DateTime.fromMillisecondsSinceEpoch(pos.timestamp?.toInt() ?? DateTime.now().millisecondsSinceEpoch);

    if (pos.accuracy > 25) return;

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

    final point = RidePointEntity(
      rideId: state.ride!.id,
      timestamp: timestamp,
      lat: pos.latitude,
      lng: pos.longitude,
      speedMs: speedMs,
      acceleration: accel,
      jerk: jerk,
      altitudeM: pos.altitude,
    );

    _lastPoint = point;

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
    });

    if (_pointBuffer.length >= _bufferFlushSize) {
      _flushPointBuffer();
    }

    final alert = _detector.detect(
      jerk: jerk,
      speedMs: speedMs,
      elapsedSeconds: state.elapsed.inSeconds,
    );

    if (alert != RideAlert.none && alert != state.activeAlert) {
      HapticService.alertPattern();
    }

    final alertToShow = alert != RideAlert.none ? alert : state.activeAlert;
    final newPolyline = [...state.polyline, LatLng(pos.latitude, pos.longitude)];
    state = state.copyWith(
      currentSpeedMs: speedMs,
      maxSpeedMs: _maxSpeed,
      distanceM: _totalDistance,
      polyline: newPolyline,
      activeAlert: alertToShow,
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

  Future<void> pauseRide() async {
    if (state.status != RecordingStatus.active) return;
    _flushPointBuffer();
    _accumulatedDuration = state.elapsed;
    _activeStart = null;
    _locationSub?.pause();
    _accelSub?.pause();
    state = state.copyWith(status: RecordingStatus.paused);
  }

  Future<void> resumeRide() async {
    if (state.status != RecordingStatus.paused) return;
    _activeStart = DateTime.now();
    _locationSub?.resume();
    _accelSub?.resume();
    state = state.copyWith(status: RecordingStatus.active);
  }

  Future<String?> stopRide() async {
    if (state.status != RecordingStatus.active && state.status != RecordingStatus.paused) {
      return null;
    }

    _locationSub?.cancel();
    _accelSub?.cancel();
    _elapsedTimer?.cancel();
    _flushTimer?.cancel();

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

    await HapticService.rideStop();

    final rideId = ride.id;
    state = const RideRecordingState();
    return rideId;
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

  Future<void> recoverCrashRide() async {
    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString('active_ride_id');
    if (rideId == null) return;

    await _clearRecordingState();
    final ride = await _rideDao.getById(rideId);
    if (ride != null) {
      await _rideDao.finalizeRide(rideId, {
        'end_time': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _accelSub?.cancel();
    _elapsedTimer?.cancel();
    _flushTimer?.cancel();
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
