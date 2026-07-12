import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
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
  final double distanceM;
  final Duration elapsed;
  final RideAlert activeAlert;
  final String? error;
  // Live sensor data shown on UI
  final double sensorAccelMs2;

  const RideRecordingState({
    this.status = RecordingStatus.idle,
    this.ride,
    this.polyline = const [],
    this.currentSpeedMs = 0,
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

  Future<bool> _requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  Future<void> startRide() async {
    if (state.status != RecordingStatus.idle) return;
    state = state.copyWith(status: RecordingStatus.starting);

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
      distanceM: 0,
      elapsed: Duration.zero,
      activeAlert: RideAlert.none,
    );

    await HapticService.rideStart();
    _startLocationStream();
    _startSensorStream();
    _startTimer();
  }

  void _startLocationStream() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
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

    // Magnitude of linear acceleration vector
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    // Signed: positive if accelerating, negative if braking (use x-axis as proxy)
    final signed = event.x.abs() > event.y.abs() ? event.x : event.y;
    final signedMagnitude = signed < 0 ? -magnitude : magnitude;

    // Low-pass filter to smooth sensor noise
    _filteredAccel = _alpha * signedMagnitude + (1 - _alpha) * _filteredAccel;

    // Update UI with filtered sensor value
    if (mounted) {
      state = state.copyWith(sensorAccelMs2: _filteredAccel);
    }

    // Sensor-based rapid event detection (2-second cooldown)
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

    final now = DateTime.now();
    final speedMs = pos.speed < 0 ? 0.0 : pos.speed;

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
        currentTime: now,
      );
      accel = result.acceleration;
      jerk = result.jerk;
      distDelta = result.distanceDeltaM;
    }

    _totalDistance += distDelta;

    final point = RidePointEntity(
      rideId: state.ride!.id,
      timestamp: now,
      lat: pos.latitude,
      lng: pos.longitude,
      speedMs: speedMs,
      acceleration: accel,
      jerk: jerk,
      altitudeM: pos.altitude,
    );

    _lastPoint = point;

    _pointDao.insert({
      'ride_id': point.rideId,
      'timestamp': point.timestamp.toIso8601String(),
      'lat': point.lat,
      'lng': point.lng,
      'speed_ms': point.speedMs,
      'acceleration': point.acceleration,
      'jerk': point.jerk,
      'altitude_m': point.altitudeM,
    });

    // GPS-based alert (overspeed + fatigue, since braking/accel handled by sensor)
    final alert = _detector.detect(
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
  }

  Future<void> pauseRide() async {
    if (state.status != RecordingStatus.active) return;
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

  @override
  void dispose() {
    _locationSub?.cancel();
    _accelSub?.cancel();
    _elapsedTimer?.cancel();
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
