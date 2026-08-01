@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Exercises BikeDao.delete against a REAL in-memory SQLite database.
///
/// This suite exists because of a shipped bug: `BikeDao.delete` opened a
/// transaction and then called `RideDao.deleteForBike()` from inside it, which
/// grabbed the outer connection and opened a *second* transaction on it.
/// sqflite serializes per connection, so the inner call waited for the outer
/// transaction to commit while the outer transaction waited for the inner call
/// to return — a deadlock. It never completed and never threw; deleting a bike
/// simply did nothing, forever.
///
/// A mocked DAO cannot catch that. The whole point here is real statements on
/// a real connection.
///
/// Verified by reintroducing the bug: with the old implementation this suite
/// **hangs and never completes**. Note that the `@Timeout` above does NOT
/// cleanly abort it — the deadlock blocks inside sqflite's isolate, below the
/// level the test timeout can interrupt — so a regression presents as a stuck
/// run, not a tidy red failure. That's still detectable (CI times out), but
/// don't expect a neat assertion message: if this file ever hangs, the cause
/// is almost certainly a DAO calling another DAO from inside a transaction.
void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seedBike(String bikeId, {String userId = 'u1'}) async {
    await db.insert('bikes', {
      'id': bikeId,
      'user_id': userId,
      'brand': 'Yamaha',
      'model': 'RD350',
      'is_active': 0,
      'total_distance_m': 0,
      'ride_count': 0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<void> seedRide(String rideId, String bikeId, {int points = 0}) async {
    await db.insert('rides', {
      'id': rideId,
      'user_id': 'u1',
      'bike_id': bikeId,
      'start_time': DateTime(2026, 1, 1).toIso8601String(),
      'distance_m': 0,
      'hard_brake_count': 0,
      'rapid_accel_count': 0,
      'high_jerk_count': 0,
      'status': 'completed',
      'synced': 0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    for (var i = 0; i < points; i++) {
      await db.insert('ride_points', {
        'ride_id': rideId,
        'lat': 23.8 + i * 0.001,
        'lng': 90.4 + i * 0.001,
        'speed_ms': 10.0,
        'timestamp': DateTime(2026, 1, 1).add(Duration(seconds: i)).toIso8601String(),
      });
    }
  }

  Future<void> seedMaintenance(String id, String bikeId) async {
    await db.insert('maintenance_logs', {
      'id': id,
      'bike_id': bikeId,
      'service_type': 'oilChange',
      'date': DateTime(2026, 1, 1).toIso8601String(),
      'odometer_km': 1000,
      'synced': 0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<int> count(String table, String where, List<Object?> args) async {
    final rows = await db.query(table, where: where, whereArgs: args);
    return rows.length;
  }

  group('BikeDao.delete', () {
    // The regression test. Before the fix this never completed, so the
    // @Timeout above is load-bearing: a reintroduced deadlock fails here
    // instead of hanging the whole suite.
    test('completes for a bike that has rides (the deadlock case)', () async {
      await seedBike('b1');
      await seedRide('r1', 'b1', points: 3);

      await BikeDao().delete('b1');

      expect(await count('bikes', 'id = ?', ['b1']), 0);
    });

    test('removes the bike', () async {
      await seedBike('b1');
      await BikeDao().delete('b1');
      expect(await count('bikes', 'id = ?', ['b1']), 0);
    });

    test('cascades to that bike\'s rides and their GPS points', () async {
      await seedBike('b1');
      await seedRide('r1', 'b1', points: 5);
      await seedRide('r2', 'b1', points: 2);

      await BikeDao().delete('b1');

      expect(await count('rides', 'bike_id = ?', ['b1']), 0);
      expect(await count('ride_points', 'ride_id = ?', ['r1']), 0);
      expect(await count('ride_points', 'ride_id = ?', ['r2']), 0);
    });

    test('cascades to maintenance logs', () async {
      await seedBike('b1');
      await seedMaintenance('m1', 'b1');

      await BikeDao().delete('b1');

      expect(await count('maintenance_logs', 'bike_id = ?', ['b1']), 0);
    });

    test('leaves other bikes and their data completely untouched', () async {
      await seedBike('b1');
      await seedBike('b2');
      await seedRide('r1', 'b1', points: 2);
      await seedRide('r2', 'b2', points: 4);
      await seedMaintenance('m1', 'b1');
      await seedMaintenance('m2', 'b2');

      await BikeDao().delete('b1');

      expect(await count('bikes', 'id = ?', ['b2']), 1);
      expect(await count('rides', 'bike_id = ?', ['b2']), 1);
      expect(await count('ride_points', 'ride_id = ?', ['r2']), 4);
      expect(await count('maintenance_logs', 'bike_id = ?', ['b2']), 1);
    });

    test('is a no-op for an unknown id rather than throwing', () async {
      await seedBike('b1');
      await BikeDao().delete('does-not-exist');
      expect(await count('bikes', 'id = ?', ['b1']), 1);
    });

    test('is idempotent — deleting twice is harmless', () async {
      await seedBike('b1');
      await seedRide('r1', 'b1', points: 1);

      await BikeDao().delete('b1');
      await BikeDao().delete('b1');

      expect(await count('bikes', 'id = ?', ['b1']), 0);
    });

    test('handles a bike with no rides and no logs', () async {
      await seedBike('b1');
      await BikeDao().delete('b1');
      expect(await count('bikes', 'id = ?', ['b1']), 0);
    });
  });
}
