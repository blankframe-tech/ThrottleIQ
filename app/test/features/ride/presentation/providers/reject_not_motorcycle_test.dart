@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/presentation/providers/auto_tracking_provider.dart';

/// "Not a motorcycle ride" (#56): rejecting an auto-detected bus/car trip
/// deletes it and takes its distance back off the bike it was credited to.
/// Real SQLite, per the QA gate (no DAO mocks).
void main() {
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Yamaha',
      'model': 'FZ',
      'is_active': 1,
      'total_distance_m': 7000.0,
      'ride_count': 2,
      'synced': 1,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    await db.insert('rides', {
      'id': 'r1',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': DateTime(2026, 1, 2).toIso8601String(),
      'distance_m': 5000.0,
      'status': 'completed',
      'is_auto': 1,
      'bike_confidence': 'low',
      'synced': 1,
      'created_at': DateTime(2026, 1, 2).toIso8601String(),
    });
    // What stopRide does for the auto-detected ride.
    await BikeDao().incrementStats('b1', 5000.0);
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<Map<String, Object?>> bike() async =>
      (await db.query('bikes', where: 'id = ?', whereArgs: ['b1'])).single;

  test('deletes and tombstones the ride and reverses its bike stats, once',
      () async {
    final ride = RideModel.fromMap((await db.query('rides')).single);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final attribution = container.read(rideAttributionProvider);

    await attribution.rejectAsNotMotorcycle(ride);

    expect(await db.query('rides'), isEmpty);
    expect(await RideDao().deletedIds(), {'r1'});
    var b = await bike();
    expect(b['total_distance_m'], 7000.0);
    expect(b['ride_count'], 2);
    expect(b['synced'], 0);

    // A double tap / retry finds no row and takes nothing more off.
    await attribution.rejectAsNotMotorcycle(ride);
    b = await bike();
    expect(b['total_distance_m'], 7000.0);
    expect(b['ride_count'], 2);
  });
}
