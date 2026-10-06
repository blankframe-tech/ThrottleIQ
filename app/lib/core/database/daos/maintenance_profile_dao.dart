import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// The smaller per-bike maintenance tables added in v20: setup profile,
/// paperwork expiries and open quick-check issues. Each is tiny and read
/// whole per bike.
class MaintenanceProfileDao {
  Future<Map<String, dynamic>?> getProfile(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('bike_maintenance_profiles',
        where: 'bike_id = ?', whereArgs: [bikeId], limit: 1);
    return rows.firstOrNull;
  }

  Future<void> upsertProfile(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('bike_maintenance_profiles', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPaperwork(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('bike_paperwork',
        where: 'bike_id = ?', whereArgs: [bikeId], orderBy: 'expires_on');
  }

  Future<void> upsertPaperwork(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('bike_paperwork', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePaperwork(String bikeId, String kind) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('bike_paperwork',
        where: 'bike_id = ? AND kind = ?', whereArgs: [bikeId, kind]);
  }

  Future<List<Map<String, dynamic>>> openPrecheckIssues(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('precheck_issues',
        where: 'bike_id = ? AND resolved_at IS NULL',
        whereArgs: [bikeId],
        orderBy: 'created_at DESC');
  }

  /// Records a quick check: one issue per failed item that isn't already
  /// open, and stamps the profile's last-check time.
  Future<void> recordPrecheck({
    required String bikeId,
    required List<String> failedItems,
    required DateTime at,
    required String Function() newId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final item in failedItems) {
        final open = await txn.query('precheck_issues',
            columns: ['id'],
            where: 'bike_id = ? AND item = ? AND resolved_at IS NULL',
            whereArgs: [bikeId, item],
            limit: 1);
        if (open.isNotEmpty) continue;
        await txn.insert('precheck_issues', {
          'id': newId(),
          'bike_id': bikeId,
          'item': item,
          'created_at': at.toIso8601String(),
        });
      }
      await txn.update('bike_maintenance_profiles',
          {'last_precheck_at': at.toIso8601String()},
          where: 'bike_id = ?', whereArgs: [bikeId]);
    });
  }

  Future<void> resolvePrecheckIssue(String id, DateTime at) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('precheck_issues', {'resolved_at': at.toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }
}
