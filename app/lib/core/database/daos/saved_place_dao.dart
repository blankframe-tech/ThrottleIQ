import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Places-hub bookmarks (`saved_places`, schema v21), one row per rider per
/// place. Rows are snapshots — see `DatabaseHelper._createSavedPlacesSql`.
class SavedPlaceDao {
  static const _table = 'saved_places';

  /// The rider's saved places, most recently saved first.
  Future<List<Map<String, dynamic>>> allForUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'saved_at DESC',
    );
  }

  /// Inserts or refreshes the snapshot. Re-saving an already-saved place
  /// updates its details (a renamed garage, a new phone number) but keeps its
  /// original `saved_at`, so the list order doesn't jump around.
  Future<void> upsert(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.database;
    final updated = await db.update(
      _table,
      Map.of(row)..remove('saved_at'),
      where: 'user_id = ? AND place_id = ?',
      whereArgs: [row['user_id'], row['place_id']],
    );
    if (updated == 0) {
      await db.insert(_table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> remove(String userId, String placeId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      _table,
      where: 'user_id = ? AND place_id = ?',
      whereArgs: [userId, placeId],
    );
  }
}
