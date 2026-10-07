import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class RidePointDao {
  Future<void> insertBatch(List<Map<String, dynamic>> points) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final p in points) {
      batch.insert('ride_points', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insert(Map<String, dynamic> point) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('ride_points', point);
  }

  Future<List<Map<String, dynamic>>> getSampledForRide(String rideId, int budget) async {
    final db = await DatabaseHelper.instance.database;
    final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM ride_points WHERE ride_id = ?', [rideId]);
    final count = (countRes.first['c'] as int?) ?? 0;
    if (count <= budget) {
      return db.query('ride_points', columns: ['lat', 'lng'], where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'timestamp ASC');
    }
    final step = count ~/ budget;
    return db.rawQuery('''
      SELECT lat, lng
      FROM (
        SELECT lat, lng, ROW_NUMBER() OVER(ORDER BY timestamp ASC) as rn
        FROM ride_points
        WHERE ride_id = ?
      )
      WHERE rn % ? = 0 OR rn = 1 OR rn = ?
    ''', [rideId, step, count]);
  }

  Future<List<Map<String, dynamic>>> getForRide(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('ride_points',
        where: 'ride_id = ?',
        whereArgs: [rideId],
        orderBy: 'timestamp ASC');
  }

  Future<List<Map<String, dynamic>>> getAllByRideId(String rideId) async {
    return getForRide(rideId);
  }

  Future<List<Map<String, dynamic>>> getByRideId(String rideId) async {
    return getForRide(rideId);
  }

  Future<void> deleteForRide(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('ride_points', where: 'ride_id = ?', whereArgs: [rideId]);
  }
}
