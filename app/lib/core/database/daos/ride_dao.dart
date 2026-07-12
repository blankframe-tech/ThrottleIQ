import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class RideDao {
  Future<void> insert(Map<String, dynamic> ride) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('rides', ride, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('rides',
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, 'completed'],
        orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> getAllForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('rides',
        where: 'bike_id = ? AND status = ?',
        whereArgs: [bikeId, 'completed'],
        orderBy: 'start_time DESC');
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('rides', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> update(Map<String, dynamic> ride) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', ride, where: 'id = ?', whereArgs: [ride['id']]);
  }

  Future<void> finalizeRide(String id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'rides',
      {...data, 'status': 'completed', 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('rides', where: 'synced = 0 AND status = ?', whereArgs: ['completed']);
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncedStatus(String id, bool synced) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('rides', {'synced': synced ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
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
}
