import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Exercises RideDao.getUnsynced/finalizeRide against a REAL in-memory
/// SQLite database — regression cover for docs/Issues.md §33.1 and §33.3.
///
/// §33.1: `getUnsynced()` used to have no `user_id` filter at all, so
/// SyncManager's upload pass would happily hand a DIFFERENT rider's
/// still-unsynced rides to whichever account is currently signed in on a
/// shared device. §33.3: `finalizeRide` used to hardcode `status:
/// 'completed'` after spreading the caller's data, so a caller-supplied
/// status (crash detection writing `'crash'`, a dismissed false positive
/// writing `'active'`) was always silently overwritten.
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
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seedRide(
    String rideId, {
    required String userId,
    String status = 'completed',
    int synced = 0,
  }) async {
    await db.insert('rides', {
      'id': rideId,
      'user_id': userId,
      'bike_id': 'bike-1',
      'start_time': DateTime(2026, 1, 1).toIso8601String(),
      'distance_m': 0,
      'status': status,
      'synced': synced,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  group('RideDao.getUnsynced', () {
    test('only returns rows for the given userId (§33.1)', () async {
      await seedRide('ride-alice', userId: 'alice');
      await seedRide('ride-bob', userId: 'bob');

      final aliceUnsynced = await rideDao.getUnsynced('alice');
      final bobUnsynced = await rideDao.getUnsynced('bob');

      expect(aliceUnsynced.map((r) => r['id']), ['ride-alice']);
      expect(bobUnsynced.map((r) => r['id']), ['ride-bob']);
    });

    test('excludes already-synced and non-completed rows', () async {
      await seedRide('ride-synced', userId: 'alice', synced: 1);
      await seedRide('ride-active', userId: 'alice', status: 'active');
      await seedRide('ride-due', userId: 'alice');

      final unsynced = await rideDao.getUnsynced('alice');

      expect(unsynced.map((r) => r['id']), ['ride-due']);
    });
  });

  group('RideDao.finalizeRide', () {
    test('defaults status to completed when the caller passes none (§33.3)', () async {
      await seedRide('ride-1', userId: 'alice', status: 'active');

      await rideDao.finalizeRide('ride-1', {'distance_m': 1200.0});

      final row = await rideDao.getById('ride-1');
      expect(row!['status'], 'completed');
    });

    test('preserves a caller-supplied status instead of forcing completed (§33.3)', () async {
      await seedRide('ride-1', userId: 'alice', status: 'active');

      await rideDao.finalizeRide('ride-1', {'status': 'crash'});

      final row = await rideDao.getById('ride-1');
      expect(row!['status'], 'crash');
    });

    test('a dismissed crash can be returned to active (§33.3)', () async {
      await seedRide('ride-1', userId: 'alice', status: 'crash');

      await rideDao.finalizeRide('ride-1', {'status': 'active'});

      final row = await rideDao.getById('ride-1');
      expect(row!['status'], 'active');
    });
  });

  group('RideDao._sanitizeAndHealRides', () {
    test('automatically heals corrupted avg_speed_ms > max_speed_ms', () async {
      // Seed a corrupted ride like the 304 km/h bug: max = 13.0 m/s (~47 km/h), avg = 84.5 m/s (~304 km/h)
      // distance = 11020m, duration = 1789s -> true avg = 6.16 m/s (~22.2 km/h)
      await db.insert('rides', {
        'id': 'corrupted-ride',
        'user_id': 'rider-bob',
        'bike_id': 'bike-1',
        'start_time': DateTime(2026, 8, 30, 10, 0).toIso8601String(),
        'distance_m': 11020.0,
        'duration_s': 1789,
        'max_speed_ms': 13.0,
        'avg_speed_ms': 84.5,
        'status': 'completed',
        'synced': 1,
        'created_at': DateTime(2026, 8, 30, 10, 0).toIso8601String(),
      });

      final rows = await rideDao.getAllForUser('rider-bob');
      expect(rows.length, 1);
      final healed = rows.first;
      // Should heal to distance / duration: 11020 / 1789 = 6.16 m/s
      expect(healed['avg_speed_ms'], closeTo(6.16, 0.05));

      // Wait a tick for unawaited update to commit
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Query raw db row to confirm SQLite row is updated
      final rawRow = (await db.query('rides', where: 'id = ?', whereArgs: ['corrupted-ride'])).first;
      expect(rawRow['avg_speed_ms'], closeTo(6.16, 0.05));
    });
  });

  group('RideDao.deleteAllForUser', () {
    test('deletes all rides and points for user', () async {
      await seedRide('r-1', userId: 'user-to-delete');
      await seedRide('r-2', userId: 'user-to-delete');
      await seedRide('r-3', userId: 'other-user');
      await db.insert('ride_points', {
        'ride_id': 'r-1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'lat': 23.8,
        'lng': 90.4,
        'speed_ms': 10.0,
      });

      await rideDao.deleteAllForUser('user-to-delete');

      expect(await rideDao.getAllForUser('user-to-delete'), isEmpty);
      expect((await rideDao.getAllForUser('other-user')).length, 1);
      final points = await db.query('ride_points', where: 'ride_id = ?', whereArgs: ['r-1']);
      expect(points, isEmpty);
    });
  });
}
