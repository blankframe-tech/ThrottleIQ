import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class MaintenanceDao {
  Future<void> insert(Map<String, dynamic> log) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('maintenance_logs', log, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Inserts every row of one visit atomically, so a visit is never left
  /// half-logged.
  Future<void> insertAll(List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final log in logs) {
        await txn.insert('maintenance_logs', log,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('maintenance_logs',
        where: 'bike_id = ?', whereArgs: [bikeId], orderBy: 'date DESC');
  }

  /// Plain local delete with no tombstone. Only safe for rows that never
  /// reached the cloud; use [deleteWithTombstone] for anything the rider
  /// deletes (§94.2).
  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('maintenance_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes logs locally AND records tombstones, in one transaction
  /// (§94.2). Any queued upload of them is dropped too, so the outbox can't
  /// re-create a log in Firestore after its remote delete. SyncManager
  /// deletes the remote copies and marks the tombstones synced.
  Future<void> deleteWithTombstone(List<String> ids, {String? userId}) async {
    if (ids.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete('maintenance_logs', where: 'id = ?', whereArgs: [id]);
        await txn.delete('outbox',
            where: 'id = ?', whereArgs: ['maintenance:$id']);
        await txn.insert(
          'deleted_maintenance_logs',
          {'id': id, 'user_id': userId, 'deleted_at': now, 'synced': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Log ids this device has deleted. Downloads and outbox deliveries skip
  /// these.
  Future<Set<String>> deletedIds() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_maintenance_logs', columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  Future<bool> isDeleted(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_maintenance_logs',
        columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  /// [userId]'s log tombstones whose remote copy still needs deleting.
  /// Unowned rows are included: they can only have come from this device.
  Future<List<String>> pendingRemoteDeletions(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_maintenance_logs',
        columns: ['id'],
        where: 'synced = 0 AND (user_id = ? OR user_id IS NULL)',
        whereArgs: [userId]);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> markDeletionSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('deleted_maintenance_logs', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
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
