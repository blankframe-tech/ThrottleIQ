import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/daos/ride_point_dao.dart';
import 'package:throttleiq/core/services/weather_service.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/garage/data/models/bike_model.dart';
import 'package:throttleiq/features/profile/data/repositories/profile_repository.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/domain/calculators/segment_speed_aggregator.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

/// Coordinates local storage persistence (SQLite batching, SharedPreferences interruption recovery)
/// and post-ride baseline telemetry publishing.
class RidePersistenceCoordinator {
  RidePersistenceCoordinator({
    RideDao? rideDao,
    RidePointDao? pointDao,
    BikeDao? bikeDao,
    WeatherService? weatherService,
    FirebaseFirestore? firestore,
  })  : _rideDao = rideDao ?? RideDao(),
        _pointDao = pointDao ?? RidePointDao(),
        _bikeDao = bikeDao ?? BikeDao(),
        _weatherService = weatherService ?? WeatherService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final RideDao _rideDao;
  final RidePointDao _pointDao;
  final BikeDao _bikeDao;
  final WeatherService _weatherService;
  final FirebaseFirestore _firestore;

  static const String _prefsRideId = 'active_ride_id';
  static const String _prefsStartTime = 'ride_start_time';
  static const String _prefsElapsedS = 'ride_elapsed_s';

  static const int _bufferFlushSize = 5;
  static const Duration _bufferFlushInterval = Duration(seconds: 3);
  static const int _earlyRideFlushUntil = 8;
  static const Duration _elapsedPersistInterval = Duration(seconds: 10);

  final List<Map<String, dynamic>> _pointBuffer = [];
  int _persistedPointCount = 0;
  DateTime? _lastElapsedPersist;
  Timer? _flushTimer;

  int get persistedPointCount => _persistedPointCount;
  int get bufferedPointCount => _pointBuffer.length;

  void startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_bufferFlushInterval, (_) {
      if (_pointBuffer.isNotEmpty) {
        unawaited(flushPointBuffer());
      }
    });
  }

  void resetCounts() {
    _pointBuffer.clear();
    _persistedPointCount = 0;
    _lastElapsedPersist = null;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Appends a ride point row to the batch buffer, flushing immediately if in
  /// early-ride phase or when buffer limit is reached.
  void enqueuePoint(Map<String, dynamic> row) {
    _pointBuffer.add(row);
    final flushEveryFix = _persistedPointCount < _earlyRideFlushUntil;
    if (flushEveryFix || _pointBuffer.length >= _bufferFlushSize) {
      unawaited(flushPointBuffer());
    }
  }

  /// Flushes buffered point rows to SQLite safely.
  Future<void> flushPointBuffer() async {
    if (_pointBuffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pointBuffer);
    _pointBuffer.clear();
    try {
      await _pointDao.insertBatch(batch);
      _persistedPointCount += batch.length;
    } catch (e) {
      debugPrint('[RidePersistence] Point flush failed (${batch.length} fixes): $e');
      _pointBuffer.insertAll(0, batch);
    }
  }

  /// Writes active ride marker to SharedPreferences.
  Future<void> persistRecordingState(RideEntity ride) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsRideId, ride.id);
    await prefs.setString(_prefsStartTime, ride.startTime.toIso8601String());
    await prefs.setInt(_prefsElapsedS, 0);
  }

  /// Snapshots the ride clock, throttled to 10s unless [force] is true.
  Future<void> persistElapsed(Duration elapsed, {bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastElapsedPersist != null &&
        now.difference(_lastElapsedPersist!) < _elapsedPersistInterval) {
      return;
    }
    _lastElapsedPersist = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsElapsedS, elapsed.inSeconds);
  }

  /// Clears active ride markers from SharedPreferences.
  Future<void> clearRecordingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRideId);
    await prefs.remove(_prefsStartTime);
    await prefs.remove(_prefsElapsedS);
  }

  /// Retrieves saved active ride ID if any.
  Future<String?> getSavedActiveRideId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsRideId);
  }

  /// Retrieves saved elapsed seconds if any.
  Future<int?> getSavedElapsedSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsElapsedS);
  }

  /// Contributes per-segment speeds to anonymous shared pool.
  Future<void> publishSegmentBaselines(String rideId, DateTime startTime) async {
    final rows = await _pointDao.getForRide(rideId);
    if (rows.length < 2) return;

    final segments = averageSpeedPerSegment([
      for (final r in rows)
        (
          lat: r['lat'] as double,
          lng: r['lng'] as double,
          speedMs: (r['speed_ms'] as num).toDouble()
        ),
    ]);
    if (segments.isEmpty) return;

    final weather = await _weatherService.fetchForRide(
      lat: rows.first['lat'] as double,
      lng: rows.first['lng'] as double,
      at: startTime,
    );

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

  /// Recomputes rider totals and badge definitions on completion.
  Future<void> updatePublicStats(String uid) async {
    try {
      final rideRows = await _rideDao.getAllForUser(uid);
      final bikeRows = await _bikeDao.getAllForUser(uid);
      final stats = computeRiderStats(
        rides: rideRows.map(RideModel.fromMap).toList(),
        bikes: bikeRows.map(BikeModel.fromMap).toList(),
      );
      final earnedIds =
          computeBadges(stats).where((b) => b.earned).map((b) => b.def.id).toList();
      await ProfileRepository().updatePublicStats(
        uid: uid,
        totalDistanceKm: stats.totalDistanceKm,
        totalRides: stats.totalRides,
        badgeIds: earnedIds,
      );
    } catch (_) {/* non-fatal */}
  }

  Future<void> _bestEffortWrite(String label, Future<void> Function() write) async {
    try {
      await write().timeout(kOutboxAttemptTimeout);
    } on TimeoutException {
      debugPrint('[RidePersistence] $label not confirmed within '
          '${kOutboxAttemptTimeout.inSeconds}s — queued by Firestore, moving on');
    } catch (e) {
      debugPrint('[RidePersistence] $label failed: $e');
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(flushPointBuffer());
  }
}
