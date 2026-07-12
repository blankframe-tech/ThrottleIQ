import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'ride_dao.dart';
import 'maintenance_dao.dart';

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

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final rideDao = RideDao();
      await rideDao.deleteForBike(id);
      final maintenanceDao = MaintenanceDao();
      await maintenanceDao.deleteForBike(id);
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

