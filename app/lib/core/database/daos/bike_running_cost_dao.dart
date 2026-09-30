import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Per-bike fuel price & mileage (`bike_running_costs`, schema v18).
class BikeRunningCostDao {
  Future<Map<String, dynamic>?> getForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'bike_running_costs',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsert(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'bike_running_costs',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
