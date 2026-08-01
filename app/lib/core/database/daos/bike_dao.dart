import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class BikeDao {
  Future<void> insert(Map<String, dynamic> bike) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('bikes', bike, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('bikes', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
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
  /// GPS points, and its maintenance logs.
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
      await txn.delete('bikes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setActive(String id, String userId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update('bikes', {'is_active': 0}, where: 'user_id = ?', whereArgs: [userId]);
      await txn.update('bikes', {'is_active': 1}, where: 'id = ?', whereArgs: [id]);
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
}

