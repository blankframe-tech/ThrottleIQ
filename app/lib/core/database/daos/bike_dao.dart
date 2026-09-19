import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class BikeDao {
  Future<void> insert(Map<String, dynamic> bike) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('bikes', bike, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// The rider's bikes. Archived bikes are left out unless [includeArchived]
  /// — the garage, every bike picker and the home widget want only bikes the
  /// rider still rides, while stats want every bike their rides point at.
  Future<List<Map<String, dynamic>>> getAllForUser(
    String userId, {
    bool includeArchived = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('bikes',
        where: includeArchived ? 'user_id = ?' : 'user_id = ? AND archived = 0',
        whereArgs: [userId],
        orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getArchivedForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('bikes',
        where: 'user_id = ? AND archived = 1',
        whereArgs: [userId],
        orderBy: 'created_at DESC');
  }

  /// Archives or unarchives a bike. Its rides, maintenance logs and totals
  /// are untouched — that is the whole point of archiving over [delete],
  /// which takes the bike's ride history with it (claude_sol §2.1.1).
  ///
  /// An archived bike can't stay the active one (it's hidden from every
  /// picker, so the rider couldn't switch away from it), so archiving the
  /// active bike hands "active" to the most recently added bike still in the
  /// garage, in the same transaction. `synced = 0` so the flag reaches the
  /// cloud copy.
  Future<void> setArchived(String id, bool archived) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query('bikes',
          columns: ['user_id', 'is_active'], where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final wasActive = rows.first['is_active'] == 1;
      await txn.update(
        'bikes',
        {
          'archived': archived ? 1 : 0,
          if (archived) 'is_active': 0,
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (archived && wasActive) {
        final next = await txn.query('bikes',
            columns: ['id'],
            where: 'user_id = ? AND archived = 0',
            whereArgs: [rows.first['user_id']],
            orderBy: 'created_at DESC',
            limit: 1);
        if (next.isNotEmpty) {
          await txn.update('bikes', {'is_active': 1},
              where: 'id = ?', whereArgs: [next.first['id']]);
        }
      }
    });
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('bikes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> update(Map<String, dynamic> bike) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('bikes', bike, where: 'id = ?', whereArgs: [bike['id']]);
  }

  /// Deletes a bike and everything hanging off it: its rides, those rides'
  /// GPS points, and its maintenance logs. Only for the explicit "delete bike
  /// and all its rides" action — the default is [setArchived].
  ///
  /// Every statement runs on `txn`, deliberately. The previous version called
  /// `RideDao.deleteForBike()` / `MaintenanceDao.deleteForBike()` from inside
  /// this transaction, and those each grab `DatabaseHelper.instance.database`
  /// — the *outer* connection — and (in RideDao's case) open a second
  /// transaction on it. sqflite serializes access per connection, so that
  /// inner call blocked waiting for this transaction to commit, while this
  /// transaction sat waiting for the inner call to return: a deadlock. The
  /// delete never completed and never threw, which is exactly how it
  /// presented — "I can't delete a bike from the app", with no error.
  ///
  /// Keep this self-contained. Calling another DAO's method from inside a
  /// transaction re-introduces the same deadlock.
  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final rides = await txn.query(
        'rides',
        columns: ['id'],
        where: 'bike_id = ?',
        whereArgs: [id],
      );
      for (final ride in rides) {
        await txn.delete('ride_points', where: 'ride_id = ?', whereArgs: [ride['id']]);
      }
      await txn.delete('rides', where: 'bike_id = ?', whereArgs: [id]);
      await txn.delete('maintenance_logs', where: 'bike_id = ?', whereArgs: [id]);
      await txn.delete('bike_maintenance_configs', where: 'bike_id = ?', whereArgs: [id]);
      await txn.delete('bikes', where: 'id = ?', whereArgs: [id]);

      // Tombstone, written in the SAME transaction as the delete so the two
      // can never disagree. Deleting locally is not enough on its own:
      // CloudRepository.downloadBikes re-adds "anything missing locally", so
      // without this the bike reappeared on the next sync — still selectable
      // on the record screen, still in the rider's forums. See Issues.md.
      await txn.insert(
        'deleted_bikes',
        {
          'id': id,
          'deleted_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Ids this device has deleted. The download path must skip these.
  Future<Set<String>> deletedIds() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_bikes', columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  /// Tombstones whose remote copy still needs deleting.
  Future<List<String>> pendingRemoteDeletions() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_bikes',
        columns: ['id'], where: 'synced = 0');
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Marks a tombstone's remote delete as done. The row is kept, not removed —
  /// another device that still has the bike would otherwise reintroduce it.
  Future<void> markDeletionSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('deleted_bikes', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setActive(String id, String userId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update('bikes', {'is_active': 0}, where: 'user_id = ?', whereArgs: [userId]);
      await txn.update('bikes', {'is_active': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Moves one ride's contribution from one bike to another.
  ///
  /// Needed because auto-detected rides are attributed by guess (see
  /// `BikeAttributionConfidence`) and the rider can correct that afterwards.
  /// A correction that only rewrote `rides.bike_id` would leave the distance
  /// and ride count on the wrong bike forever — and since maintenance
  /// intervals are distance-based, that means both bikes' service schedules
  /// stay wrong even though history now looks right.
  ///
  /// One transaction, and `total_distance_m` is floored at zero: a bike whose
  /// stats were recomputed or edited at some point could otherwise be driven
  /// negative by subtracting a ride it never fully accumulated.
  Future<void> moveRideStats({
    required String fromBikeId,
    required String toBikeId,
    required double distanceM,
  }) async {
    if (fromBikeId == toBikeId) return;
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.rawUpdate("""
        UPDATE bikes SET
          total_distance_m = MAX(0, total_distance_m - ?),
          ride_count = MAX(0, ride_count - 1),
          synced = 0
        WHERE id = ?
      """, [distanceM, fromBikeId]);
      await txn.rawUpdate("""
        UPDATE bikes SET
          total_distance_m = total_distance_m + ?,
          ride_count = ride_count + 1,
          synced = 0
        WHERE id = ?
      """, [distanceM, toBikeId]);
    });
  }

  Future<void> incrementStats(String id, double distanceM) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate('''
      UPDATE bikes SET
        total_distance_m = total_distance_m + ?,
        ride_count = ride_count + 1,
        last_ride_at = ?,
        synced = 0
      WHERE id = ?
    ''', [distanceM, DateTime.now().toIso8601String(), id]);
  }

  Future<void> updateOdometer(String id, double odometerKm) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'bikes',
      {
        'odometer_km': odometerKm,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateImagePath(String id, String imagePath) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'bikes',
      {
        'image_path': imagePath,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns bikes for [userId] whose `image_path` is a local file path
  /// (i.e. not null and not a remote http/https URL) so they can be uploaded
  /// to the cloud.
  Future<List<Map<String, dynamic>>> getBikesWithLocalImages(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'bikes',
      where:
          "user_id = ? AND image_path IS NOT NULL AND image_path != '' AND image_path NOT LIKE 'http://%' AND image_path NOT LIKE 'https://%'",
      whereArgs: [userId],
    );
  }
}

