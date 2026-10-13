@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/ride_point_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

void main() {
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('getLatLngForRide returns only lat/lng, in time order', () async {
    final dao = RidePointDao();
    Map<String, Object?> p(String rideId, int sec, double lat) => {
          'ride_id': rideId,
          'timestamp': DateTime(2026, 1, 1, 10, 0, sec).toIso8601String(),
          'lat': lat,
          'lng': 90.0,
          'speed_ms': 5.0,
        };
    await db.insert('ride_points', p('r1', 2, 23.2));
    await db.insert('ride_points', p('r1', 1, 23.1));
    await db.insert('ride_points', p('other', 0, 1.0));

    final rows = await dao.getLatLngForRide('r1');
    expect(rows.map((r) => r['lat']), [23.1, 23.2]);
    expect(rows.first.keys.toSet(), {'lat', 'lng'});
  });
}
