import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import '../../constants/sensor_constants.dart';
import '../database_helper.dart';

/// Matches a ride that has finished recording and belongs in the rider's
/// history. `crash` is a finished ride too — it ended because crash detection
/// fired — and leaving it out (the old `status = 'completed'` filter) meant a
/// crash ride never synced and never appeared in any list. See
/// issues §69.O10 / grill §1.2.2.
///
/// Literal rather than bound parameters so it composes into the existing
/// `where:` strings without shifting every call site's `whereArgs`.
const _finishedStatusSql = "status IN ('completed', 'crash')";

class RideDao {
  Future<void> insert(Map<String, dynamic> ride) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('rides', ride, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('rides',
        where: 'user_id = ? AND $_finishedStatusSql',
        whereArgs: [userId],
        orderBy: 'start_time DESC');
    return _sanitizeAndHealRides(db, rows);
  }

  Future<List<Map<String, dynamic>>> getAllForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('rides',
        where: 'bike_id = ? AND $_finishedStatusSql',
        whereArgs: [bikeId],
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

  /// The id of [userId]'s most recently completed ride, or null if they have
  /// none. The sole input to "which ride is still eligible for the
  /// change-bike correction" — only the ride you just finished, never an
  /// older one further back in history.
  Future<String?> getMostRecentCompletedId(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'rides',
      columns: ['id'],
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'completed'],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
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

        // issues §62 (core services): a self-heal write fired from a
        // read path has no caller to report failure to, but it must not
        // vanish silently either — a transient sqflite error (locked DB,
        // disk full) here used to be dropped into an unobserved microtask
        // with no error handler at all.
        unawaited(db.update(
          'rides',
          updates,
          where: 'id = ?',
          whereArgs: [row['id']],
        ).catchError((Object e) {
          debugPrint('[RideDao] self-heal write failed for ride ${row['id']}: $e');
          return 0;
        }));
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
  /// issues §33.3: this used to spread `data` first and hardcode
  /// `'status': 'completed'` after it, so the literal always overrode
  /// whatever status the caller asked for — `status: 'crash'` was silently
  /// rewritten to `'completed'` the instant it was written, and a dismissed
  /// crash's `status: 'active'` never stuck either. `status: 'crash'` was
  /// never actually persisted anywhere.
  ///
  /// Also resets `track_synced`: finalizing is the last point the trail can
  /// change, so whatever copy of it reached the cloud before (a resumed ride,
  /// a crash that was dismissed and re-finalized) is now stale.
  Future<void> finalizeRide(String id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'rides',
      {'status': 'completed', ...data, 'synced': 0, 'track_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// issues §33.1: scoped to [userId] — this feeds directly into
  /// SyncManager's upload pass, and an unscoped query would happily hand
  /// another rider's still-unsynced rides to whichever account is currently
  /// signed in on this device.
  ///
  /// Includes `crash` rides (§69.O10): a crash ride is the one whose record
  /// matters most, and it used to be the one that never left the phone.
  Future<List<Map<String, dynamic>>> getUnsynced(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('rides',
        where: 'user_id = ? AND synced = 0 AND $_finishedStatusSql',
        whereArgs: [userId]);
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Rides whose metadata is in the cloud but whose GPS trail isn't yet.
  ///
  /// Separate from [getUnsynced] because the two uploads fail independently:
  /// `synced` flips as soon as the ride doc lands, and a trail upload that
  /// failed afterwards used to be forgotten for good. See grill §1.3.2.
  Future<List<Map<String, dynamic>>> getTrackUnsynced(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('rides',
        columns: ['id'],
        where: 'user_id = ? AND synced = 1 AND track_synced = 0 '
            'AND $_finishedStatusSql',
        whereArgs: [userId]);
  }

  Future<void> markTrackSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', {'track_synced': 1},
        where: 'id = ?', whereArgs: [id]);
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
      where: 'user_id = ? AND $_finishedStatusSql '
          'AND start_time >= ? AND start_time < ?',
      whereArgs: [
        userId,
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
