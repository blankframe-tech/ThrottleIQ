import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/daos/auto_detection_dao.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/calculators/auto_detection_policy.dart';
import '../../domain/calculators/auto_ride_reconciler.dart';
import 'daily_ride_summary_repository.dart' show stagedFixFromRow;

/// Credits the distance of a background-detected trip to a bike's odometer
/// (issues §93.1, decided 2026-10-06: yes, forgotten rides count).
///
/// Since detections stopped becoming ride rows, a rider who relies on
/// auto-tracking added nothing to their bike's km — so oil changes and chain
/// lubes came due later and later than they should. This puts that distance
/// back, without making the trip a ride:
///
/// - **Only riding nobody recorded.** Fixes inside any ride window (finished
///   or still recording) are cut out first — the same [runsClearOfRides]
///   split the daily summary uses — so a journey the rider recorded by hand
///   is never counted twice (§90.C3).
/// - **Only things that look like a ride.** The trimmed remainder must pass
///   the reconciler's distance and peak-speed floors, so a walk or a car-park
///   shuffle adds nothing.
/// - **Once.** One `detection_odometer_credits` row per detection, written
///   in the same transaction as the bike update.
/// - **To the active bike.** The bike the rider has selected is the best
///   guess of what they were riding; a detection carries no bike of its own.
///
/// The credit lands on the bike's `odometer_km` (its baseline) rather than
/// its ride totals, so ride counts and riding stats stay recorded-only.
class DetectedOdometerCredit {
  DetectedOdometerCredit({
    AutoDetectionDao? detectionDao,
    RideDao? rideDao,
    AutoRideReconciler? reconciler,
  })  : _detectionDao = detectionDao ?? AutoDetectionDao(),
        _rideDao = rideDao ?? RideDao(),
        _reconciler = reconciler ?? AutoRideReconciler();

  final AutoDetectionDao _detectionDao;
  final RideDao _rideDao;
  final AutoRideReconciler _reconciler;

  /// Returns the km credited (0 when nothing qualified or it was already
  /// credited). Never throws: a failed credit must not block summarising.
  Future<double> creditDetection({
    required String userId,
    required String detectionId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query('detection_odometer_credits',
          columns: ['detection_id'],
          where: 'detection_id = ?',
          whereArgs: [detectionId],
          limit: 1);
      if (existing.isNotEmpty) return 0;

      final staged = [
        for (final r in await _detectionDao.fixesFor(detectionId))
          stagedFixFromRow(r),
      ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (staged.isEmpty) return 0;

      final windows = [
        for (final w in await _rideDao.rideWindows(userId))
          (start: w.start, end: w.end),
      ];
      final measured = measureClearDistance(
        runsClearOfRides<StagedFix>(staged, (f) => f.timestamp, windows),
        _reconciler,
      );
      if (measured == null) return 0;

      final bikeId = await _creditBikeId(db, userId);
      if (bikeId == null) return 0;

      await db.transaction((txn) async {
        await txn.insert('detection_odometer_credits', {
          'detection_id': detectionId,
          'bike_id': bikeId,
          'distance_m': measured.distanceM,
          'credited_at': DateTime.now().toIso8601String(),
          'trip_end': staged.last.timestamp.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.abort);
        await txn.rawUpdate('''
          UPDATE bikes SET
            odometer_km = COALESCE(odometer_km, 0) + ?,
            synced = 0
          WHERE id = ?
        ''', [measured.distanceM / 1000, bikeId]);
      });
      return measured.distanceM / 1000;
    } catch (e) {
      debugPrint('[odometer-credit] $detectionId skipped: $e');
      return 0;
    }
  }

  Future<String?> _creditBikeId(Database db, String userId) async {
    final rows = await db.query('bikes',
        columns: ['id'],
        where: 'user_id = ? AND archived = 0',
        whereArgs: [userId],
        orderBy: 'is_active DESC, last_ride_at DESC',
        limit: 1);
    return rows.firstOrNull?['id'] as String?;
  }
}

/// Sums the measured distance of [runs] and applies the reconciler's
/// "was this a ride" floors to the whole trip. Null when it doesn't qualify.
({double distanceM, double maxSpeedMs})? measureClearDistance(
  List<List<StagedFix>> runs,
  AutoRideReconciler reconciler,
) {
  var distance = 0.0;
  var peak = 0.0;
  for (final run in runs) {
    final m = reconciler.measure(run);
    if (m == null) continue;
    distance += m.distanceM;
    if (m.maxSpeedMs > peak) peak = m.maxSpeedMs;
  }
  if (distance < AutoRideReconciler.minDistanceM ||
      peak < AutoRideReconciler.minPeakSpeedMs) {
    return null;
  }
  return (distanceM: distance, maxSpeedMs: peak);
}
