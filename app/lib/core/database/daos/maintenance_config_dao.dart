import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class MaintenanceConfigDao {
  Future<List<Map<String, dynamic>>> getConfigsForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'bike_maintenance_configs',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
    );
  }

  /// Replaces all maintenance configuration rows for [bikeId] atomically.
  ///
  /// Self-contained transaction; never invokes another DAO inside [txn].
  Future<void> saveConfigsForBike(
      String bikeId, List<Map<String, dynamic>> configs) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'bike_maintenance_configs',
        where: 'bike_id = ?',
        whereArgs: [bikeId],
      );
      for (final config in configs) {
        await txn.insert(
          'bike_maintenance_configs',
          config,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<bool> hasCustomized(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bike_maintenance_configs WHERE bike_id = ?',
      [bikeId],
    );
    final count = Sqflite.firstIntValue(rows) ?? 0;
    return count > 0;
  }

  Future<void> deleteForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'bike_maintenance_configs',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
    );
  }
}
