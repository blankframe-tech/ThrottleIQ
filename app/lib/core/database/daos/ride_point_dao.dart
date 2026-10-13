import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class RidePointDao {
  Future<void> insertBatch(List<Map<String, dynamic>> points) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final p in points) {
      batch.insert('ride_points', p,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insert(Map<String, dynamic> point) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('ride_points', point);
  }

  Future<List<Map<String, dynamic>>> getForRide(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('ride_points',
        where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'timestamp ASC');
  }

  /// Just the coordinates, in order: what a route thumbnail needs, without
  /// reading every other column of every point (issues §101.R10).
  Future<List<Map<String, dynamic>>> getLatLngForRide(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('ride_points',
        columns: ['lat', 'lng'],
        where: 'ride_id = ?',
        whereArgs: [rideId],
        orderBy: 'timestamp ASC');
  }

  /// Just the altitude samples, in order (null where a fix had none) — what
  /// the elevation figure needs, without the rest of every point.
  Future<List<double?>> getAltitudesForRide(String rideId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('ride_points',
        columns: ['altitude_m'],
        where: 'ride_id = ?',
        whereArgs: [rideId],
        orderBy: 'timestamp ASC');
    return [for (final r in rows) (r['altitude_m'] as num?)?.toDouble()];
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
