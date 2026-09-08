import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../constants/sensor_constants.dart';
import '../database_helper.dart';

class RideDao {
  Future<void> insert(Map<String, dynamic> ride) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('rides', ride, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('rides',
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, 'completed'],
        orderBy: 'start_time DESC');
    return _sanitizeAndHealRides(db, rows);
  }

  Future<List<Map<String, dynamic>>> getAllForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('rides',
        where: 'bike_id = ? AND status = ?',
        whereArgs: [bikeId, 'completed'],
        orderBy: 'start_time DESC');
    return _sanitizeAndHealRides(db, rows);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('rides', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final healed = _sanitizeAndHealRides(db, rows);
    return healed.first;
  }

  List<Map<String, dynamic>> _sanitizeAndHealRides(
    Database db,
    List<Map<String, dynamic>> rows,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final avgSpeed = (row['avg_speed_ms'] as num?)?.toDouble();
      final maxSpeed = (row['max_speed_ms'] as num?)?.toDouble();
      final distanceM = (row['distance_m'] as num?)?.toDouble() ?? 0.0;
      final durationS = row['duration_s'] as int?;

      var healedAvg = avgSpeed;
      var healedMax = maxSpeed;
      var modified = false;

      // 1. Heal corrupted massive max speeds (> 70 m/s ~ 252 km/h)
      if (healedMax != null && healedMax > SensorConstants.maxPlausibleSpeedMs) {
        final plausibleFallback = (healedAvg != null &&
                healedAvg > 0 &&
                healedAvg <= SensorConstants.maxPlausibleSpeedMs)
            ? (healedAvg * 1.5).clamp(healedAvg, SensorConstants.maxPlausibleSpeedMs)
            : SensorConstants.maxPlausibleSpeedMs;
        healedMax = plausibleFallback;
        modified = true;
      }

      // 2. Heal missing / zero max speed for moving rides (distance > 0)
      final overallSpeed =
          (durationS != null && durationS > 0) ? (distanceM / durationS) : 0.0;
      if ((healedMax == null || healedMax <= 0) && distanceM > 0) {
        if (healedAvg != null && healedAvg > 0) {
          healedMax = healedAvg;
        } else if (overallSpeed > 0) {
          healedMax = overallSpeed.clamp(0.0, SensorConstants.maxPlausibleSpeedMs);
        }
        if (healedMax != null && healedMax > 0) {
          modified = true;
        }
      }

      // 3. Heal avg_speed > max_speed (physical impossibility)
      if (healedAvg != null &&
          healedMax != null &&
          healedMax > 0 &&
          healedAvg > healedMax) {
        final fallbackAvg = (durationS != null && durationS > 0)
            ? (distanceM / durationS).clamp(0.0, healedMax)
            : healedMax;
        healedAvg = fallbackAvg;
        modified = true;
      }

      // 4. Physical invariant: top speed can never be less than average speed
      if (healedAvg != null &&
          healedMax != null &&
          healedAvg > 0 &&
          healedMax < healedAvg) {
        healedMax = healedAvg;
        modified = true;
      }

      if (modified) {
        final copy = Map<String, dynamic>.from(row);
        if (healedAvg != null) copy['avg_speed_ms'] = healedAvg;
        if (healedMax != null) copy['max_speed_ms'] = healedMax;
        result.add(copy);

        final updates = <String, dynamic>{};
        if (healedAvg != null) updates['avg_speed_ms'] = healedAvg;
        if (healedMax != null) updates['max_speed_ms'] = healedMax;

        unawaited(db.update(
          'rides',
          updates,
          where: 'id = ?',
          whereArgs: [row['id']],
        ));
      } else {
        result.add(row);
      }
    }
    return result;
  }

  Future<void> update(Map<String, dynamic> ride) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', ride, where: 'id = ?', whereArgs: [ride['id']]);
  }

  /// Ends a ride's recording lifecycle. Defaults `status` to `'completed'` —
  /// the normal end-of-ride call never passes one — but a caller that DOES
  /// pass a `status` (crash detection writing `'crash'`, a dismissed false
  /// positive writing `'active'`) must have it win.
  ///
  /// docs/Issues.md §33.3: this used to spread `data` first and hardcode
  /// `'status': 'completed'` after it, so the literal always overrode
  /// whatever status the caller asked for — `status: 'crash'` was silently
  /// rewritten to `'completed'` the instant it was written, and a dismissed
  /// crash's `status: 'active'` never stuck either. `status: 'crash'` was
  /// never actually persisted anywhere.
  Future<void> finalizeRide(String id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'rides',
      {'status': 'completed', ...data, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// docs/Issues.md §33.1: scoped to [userId] — this feeds directly into
  /// SyncManager's upload pass, and an unscoped query would happily hand
  /// another rider's still-unsynced rides to whichever account is currently
  /// signed in on this device.
  Future<List<Map<String, dynamic>>> getUnsynced(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('rides',
        where: 'user_id = ? AND synced = 0 AND status = ?',
        whereArgs: [userId, 'completed']);
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncedStatus(String id, bool synced) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', {'synced': synced ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Completed auto-detected rides whose bike attribution the rider hasn't
  /// confirmed yet — the input to the daily confirmation prompt.
  ///
  /// Scoped to `completed` so a ride still being recorded is never offered for
  /// confirmation, and ordered oldest-first so a rider who has ignored the
  /// prompt for a few days is asked about the ride they're least likely to
  /// still remember first, while they might still remember it at all.
  Future<List<Map<String, dynamic>>> getUnconfirmedAutoRides(
    String userId, {
    int limit = 20,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'rides',
      where:
          'user_id = ? AND status = ? AND is_auto = 1 AND bike_confidence = ?',
      whereArgs: [userId, 'completed', 'low'],
      orderBy: 'start_time ASC',
      limit: limit,
    );
  }

  /// Records the rider's answer to "which bike was this?".
  ///
  /// Always sets confidence to `confirmed`, whether or not [bikeId] differs
  /// from what was guessed — "yes, that was the right bike" is as much a
  /// confirmation as a correction, and both must stop the prompt re-asking.
  ///
  /// `synced = 0` because reattribution has to reach the cloud copy too;
  /// otherwise the next download would restore the wrong bike.
  Future<void> confirmBikeAttribution(String rideId, String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'rides',
      {'bike_id': bikeId, 'bike_confidence': 'confirmed', 'synced': 0},
      where: 'id = ?',
      whereArgs: [rideId],
    );
  }

  /// Rides finishing within [day], for the daily prompt and the weekly digest.
  Future<List<Map<String, dynamic>>> getCompletedBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'rides',
      where: 'user_id = ? AND status = ? AND start_time >= ? AND start_time < ?',
      whereArgs: [
        userId,
        'completed',
        from.toIso8601String(),
        to.toIso8601String(),
      ],
      orderBy: 'start_time ASC',
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete('ride_points', where: 'ride_id = ?', whereArgs: [id]);
      await txn.delete('rides', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final rides = await txn.query('rides', where: 'bike_id = ?', whereArgs: [bikeId], columns: ['id']);
      for (final ride in rides) {
        await txn.delete('ride_points', where: 'ride_id = ?', whereArgs: [ride['id']]);
      }
      await txn.delete('rides', where: 'bike_id = ?', whereArgs: [bikeId]);
    });
  }

  Future<void> deleteAllForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final rides = await txn.query('rides', where: 'user_id = ?', whereArgs: [userId], columns: ['id']);
      for (final ride in rides) {
        await txn.delete('ride_points', where: 'ride_id = ?', whereArgs: [ride['id']]);
      }
      await txn.delete('rides', where: 'user_id = ?', whereArgs: [userId]);
    });
  }
}
