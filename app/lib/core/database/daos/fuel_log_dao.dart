import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Fuel fill-ups (schema v27). Same lifecycle as `MaintenanceDao`: rows sync
/// through the outbox, and anything the rider deletes leaves a tombstone so
/// the cloud copy is removed and never pulled back.
class FuelLogDao {
  /// Outbox entry id for a fill-up's upload.
  static String outboxId(String logId) => 'fuel:$logId';

  Future<void> upsert(Map<String, dynamic> log) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('fuel_logs', log,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// One bike's fill-ups, newest first.
  Future<List<Map<String, dynamic>>> getForBike(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('fuel_logs',
        where: 'bike_id = ?',
        whereArgs: [bikeId],
        orderBy: 'filled_at DESC, odometer_km DESC');
  }

  /// Every fill-up on [userId]'s bikes, archived bikes included (their fuel
  /// still counts in the analytics, like their rides). `fuel_logs` has no
  /// owner column of its own; ownership is via the bike.
  Future<List<Map<String, dynamic>>> getAllForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT fuel_logs.* FROM fuel_logs
      INNER JOIN bikes ON bikes.id = fuel_logs.bike_id
      WHERE bikes.user_id = ?
      ORDER BY fuel_logs.filled_at ASC
    ''', [userId]);
  }

  /// [userId]'s rows still waiting to upload.
  Future<List<Map<String, dynamic>>> unsyncedForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT fuel_logs.* FROM fuel_logs
      INNER JOIN bikes ON bikes.id = fuel_logs.bike_id
      WHERE fuel_logs.synced = 0 AND bikes.user_id = ?
    ''', [userId]);
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('fuel_logs', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes fill-ups locally AND records tombstones, in one transaction.
  /// Any queued upload is dropped too, so the outbox can't re-create a
  /// fill-up in Firestore after its remote delete.
  Future<void> deleteWithTombstone(List<String> ids, {String? userId}) async {
    if (ids.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
        await txn.delete('outbox', where: 'id = ?', whereArgs: [outboxId(id)]);
        await txn.insert(
          'deleted_fuel_logs',
          {'id': id, 'user_id': userId, 'deleted_at': now, 'synced': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Set<String>> deletedIds() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_fuel_logs', columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  Future<bool> isDeleted(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_fuel_logs',
        columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  /// [userId]'s tombstones whose remote copy still needs deleting. Unowned
  /// rows are included: they can only have come from this device.
  Future<List<String>> pendingRemoteDeletions(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('deleted_fuel_logs',
        columns: ['id'],
        where: 'synced = 0 AND (user_id = ? OR user_id IS NULL)',
        whereArgs: [userId]);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> markDeletionSynced(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('deleted_fuel_logs', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
