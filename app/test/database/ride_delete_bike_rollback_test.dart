import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// §103.2: deleting a ride from history takes its distance and count off
/// the bike, exactly once, and only for a ride that was credited to it.
void main() {
  sqfliteFfiInit();

  late Database db;
  final rideDao = RideDao();

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Yamaha',
      'model': 'R15',
      'is_active': 1,
      'total_distance_m': 0,
      'ride_count': 0,
      'synced': 1,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seedRide(String id, double distanceM,
      {String status = 'completed'}) async {
    await db.insert('rides', {
      'id': id,
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': DateTime(2026, 1, 1).toIso8601String(),
      'distance_m': distanceM,
      'status': status,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<Map<String, Object?>> bike() async =>
      (await db.query('bikes', where: 'id = ?', whereArgs: ['b1'])).single;

  test('a credited ride comes off the bike, and a repeat delete is a no-op',
      () async {
    await seedRide('r1', 12000);
    await seedRide('r2', 3000);
    // What stopRide does after finalizing each ride.
    await BikeDao().incrementStats('b1', 12000);
    await BikeDao().incrementStats('b1', 3000);

    await rideDao.deleteWithTombstone('r1', userId: 'u1');
    var b = await bike();
    expect(b['total_distance_m'], 3000);
    expect(b['ride_count'], 1);
    expect(b['synced'], 0);

    // Tombstone replay / second tap: the row is gone, nothing more comes off.
    await rideDao.deleteWithTombstone('r1', userId: 'u1');
    b = await bike();
    expect(b['total_distance_m'], 3000);
    expect(b['ride_count'], 1);
    expect(await rideDao.deletedIds(), {'r1'});
  });

  test('a ride that never reached the bike (discarded active) changes nothing',
      () async {
    await seedRide('r1', 5000);
    await BikeDao().incrementStats('b1', 5000);
    await seedRide('live', 800, status: 'active');
    await seedRide('crash', 400, status: 'crash');

    await rideDao.deleteWithTombstone('live', userId: 'u1');
    await rideDao.deleteWithTombstone('crash', userId: 'u1');

    final b = await bike();
    expect(b['total_distance_m'], 5000);
    expect(b['ride_count'], 1);
  });

  test('never drives the bike below zero', () async {
    // e.g. the bike's miles were reset on archive after the ride.
    await seedRide('r1', 9000);
    await rideDao.deleteWithTombstone('r1', userId: 'u1');
    final b = await bike();
    expect(b['total_distance_m'], 0);
    expect(b['ride_count'], 0);
  });
}
