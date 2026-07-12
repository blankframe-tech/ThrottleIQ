import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class MaintenanceDao {
  Future<void> insert(Map<String, dynamic> log) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('maintenance_logs', log, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('maintenance_logs',
        where: 'bike_id = ?', whereArgs: [bikeId], orderBy: 'date DESC');
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('maintenance_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('maintenance_logs', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('maintenance_logs', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('maintenance_logs', where: 'bike_id = ?', whereArgs: [bikeId]);
  }
}
