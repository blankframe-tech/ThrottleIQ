import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/domain/calculators/final_ride_stats.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

/// Schema v28: `updated_at` for last-writer-wins sync (C4, critique B10) and
/// ride times stored as UTC (B13).
void main() {
  sqfliteFfiInit();

  late Database db;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  });
  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  bool isUtcIso(Object? v) => v is String && v.endsWith('Z');

  test('schemaVersion is 28 or later', () {
    expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(28));
  });

  test('fresh schema has updated_at and the touch trigger on every LWW table',
      () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    for (final t in DatabaseHelper.lwwTables) {
      final cols = await db.rawQuery('PRAGMA table_info($t)');
      expect(cols.any((c) => c['name'] == 'updated_at'), isTrue, reason: t);
    }
    final triggers = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name");
    expect(triggers.map((r) => r['name']), [
      'bikes_touch_updated_at',
      'maintenance_logs_touch_updated_at',
      'rides_touch_updated_at',
    ]);
  });

  group('27 → 28 upgrade', () {
    // Pre-v28 rows: device-local times with no offset.
    const start = '2026-10-13T08:15:00.000';
    const end = '2026-10-13T09:00:30.500';

    Future<void> seedV27() async {
      await db.execute('''
        CREATE TABLE bikes (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          created_at TEXT NOT NULL, last_ride_at TEXT, archived_at TEXT,
          synced INTEGER NOT NULL DEFAULT 0)
      ''');
      await db.execute('''
        CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          bike_id TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT,
          distance_m REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'active',
          synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
      ''');
      await db.execute('''
        CREATE TABLE maintenance_logs (id TEXT PRIMARY KEY,
          bike_id TEXT NOT NULL, service_type TEXT NOT NULL,
          date TEXT NOT NULL, odometer_km REAL NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
      ''');
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u',
        'created_at': '2026-01-01T10:00:00.000',
        'last_ride_at': '2026-10-13T09:00:30.500',
        'synced': 1,
      });
      await db.insert('rides', {
        'id': 'done',
        'user_id': 'u',
        'bike_id': 'b1',
        'start_time': start,
        'end_time': end,
        'distance_m': 12345.6,
        'status': 'completed',
        'synced': 1,
        'created_at': start,
      });
      // Still unsynced at upgrade time, with no end yet.
      await db.insert('rides', {
        'id': 'open',
        'user_id': 'u',
        'bike_id': 'b1',
        'start_time': start,
        'status': 'active',
        'synced': 0,
        'created_at': start,
      });
      await db.insert('maintenance_logs', {
        'id': 'm1',
        'bike_id': 'b1',
        'service_type': 'oilChange',
        'date': '2026-09-01T00:00:00.000',
        'odometer_km': 1500,
        'synced': 1,
        'created_at': '2026-09-01T12:00:00.000',
      });
    }

    test('keeps every row, rewrites ride times as UTC, backfills updated_at',
        () async {
      await seedV27();
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 27, 28);

      final done =
          (await db.query('rides', where: 'id = ?', whereArgs: ['done']))
              .single;
      expect(done['distance_m'], 12345.6);
      expect(done['status'], 'completed');
      expect(done['synced'], 1, reason: 'a format rewrite is not an edit');
      expect(isUtcIso(done['start_time']), isTrue);
      expect(isUtcIso(done['end_time']), isTrue);
      // The same instant the phone meant: legacy strings are device-local.
      expect(DateTime.parse(done['start_time'] as String),
          DateTime.parse(start).toUtc());
      expect(DateTime.parse(done['end_time'] as String),
          DateTime.parse(end).toUtc());
      expect(done['created_at'], done['start_time']);
      expect(done['updated_at'], done['end_time'],
          reason: 'finalize is the last write a ride gets');

      final open =
          (await db.query('rides', where: 'id = ?', whereArgs: ['open']))
              .single;
      expect(open['end_time'], isNull);
      expect(open['synced'], 0);
      expect(open['updated_at'], open['start_time'],
          reason: 'no end yet: the start is the best stamp');

      final bike = (await db.query('bikes')).single;
      expect(DateTime.parse(bike['updated_at'] as String),
          DateTime.parse('2026-10-13T09:00:30.500').toUtc(),
          reason: 'latest of created, last ridden and archived');
      expect(bike['created_at'], '2026-01-01T10:00:00.000',
          reason: 'bike times keep their format');

      final log = (await db.query('maintenance_logs')).single;
      expect(log['odometer_km'], 1500);
      expect(DateTime.parse(log['updated_at'] as String),
          DateTime.parse('2026-09-01T12:00:00.000').toUtc());
    });

    test('is re-runnable: a second pass changes nothing', () async {
      await seedV27();
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 27, 28);
      final first = [
        ...await db.query('rides', orderBy: 'id'),
        ...await db.query('bikes'),
        ...await db.query('maintenance_logs'),
      ];
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 27, 28);
      expect([
        ...await db.query('rides', orderBy: 'id'),
        ...await db.query('bikes'),
        ...await db.query('maintenance_logs'),
      ], first);
    });

    test('the trigger stamps later edits, not the backfill', () async {
      await seedV27();
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 27, 28);
      final backfilled =
          (await db.query('rides', where: 'id = ?', whereArgs: ['open']))
              .single['updated_at'] as String;

      await db.update('rides', {'distance_m': 10, 'synced': 0},
          where: 'id = ?', whereArgs: ['open']);
      final stamped =
          (await db.query('rides', where: 'id = ?', whereArgs: ['open']))
              .single['updated_at'] as String;
      expect(isUtcIso(stamped), isTrue);
      expect(
          DateTime.parse(stamped).isAfter(DateTime.parse(backfilled)), isTrue);
    });
  });

  group('the touch trigger', () {
    setUp(() async {
      await db.execute('PRAGMA foreign_keys = ON');
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u',
        'brand': 'Yamaha',
        'model': 'FZ',
        'synced': 1,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await db.insert('rides', {
        'id': 'r1',
        'user_id': 'u',
        'bike_id': 'b1',
        'start_time': '2026-01-01T00:00:00.000Z',
        'status': 'completed',
        'synced': 1,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
    });

    Future<Map<String, Object?>> row(String table, String id) async =>
        (await db.query(table, where: 'id = ?', whereArgs: [id])).single;

    test('a partial edit through a DAO moves updated_at', () async {
      await RideDao().confirmBikeAttribution('r1', 'b1');
      await BikeDao().updateOdometer('b1', 4200);
      for (final t in ['rides', 'bikes']) {
        final r = await row(t, t == 'rides' ? 'r1' : 'b1');
        expect(r['synced'], 0, reason: t);
        expect(
            DateTime.parse(r['updated_at'] as String)
                .isAfter(DateTime.utc(2026, 1, 2)),
            isTrue,
            reason: t);
      }
    });

    test('marking synced (or a download) leaves updated_at alone', () async {
      await db.update('rides', {'synced': 1, 'distance_m': 5},
          where: 'id = ?', whereArgs: ['r1']);
      expect(
          (await row('rides', 'r1'))['updated_at'], '2026-01-01T00:00:00.000Z');
    });

    test('an explicit updated_at wins over the trigger', () async {
      await db.update(
          'rides', {'synced': 0, 'updated_at': '2026-05-05T05:05:05.000Z'},
          where: 'id = ?', whereArgs: ['r1']);
      expect(
          (await row('rides', 'r1'))['updated_at'], '2026-05-05T05:05:05.000Z');
    });

    test('finalizeRide stores end_time as UTC and stamps the edit', () async {
      await RideDao().finalizeRide(
          'r1',
          buildFinalRideStats(
            endTime: DateTime(2026, 1, 1, 6),
            distanceM: 1000,
            maxSpeedMs: 10,
            speedSum: 50,
            speedCount: 10,
            movingMilliseconds: 500000,
            movingSeconds: 500,
            durationSeconds: 600,
            hardBrakeCount: 0,
            rapidAccelCount: 0,
            highJerkCount: 0,
            overspeedCount: 0,
          ));
      final r = await row('rides', 'r1');
      expect(isUtcIso(r['end_time']), isTrue);
      expect(DateTime.parse(r['end_time'] as String),
          DateTime(2026, 1, 1, 6).toUtc());
      expect(r['updated_at'], isNot('2026-01-01T00:00:00.000Z'));
    });
  });

  group('RideModel times', () {
    test('writes UTC and reads back the same local instant', () {
      final local = DateTime(2026, 10, 14, 7, 30);
      final map = RideModel.toMap(
          RideEntity(id: 'r', userId: 'u', bikeId: 'b', startTime: local));
      expect(map['start_time'], local.toUtc().toIso8601String());
      expect(isUtcIso(map['updated_at']), isTrue);
      final back = RideModel.fromMap({
        ...map,
        'distance_m': 0,
        'hard_brake_count': 0,
        'rapid_accel_count': 0,
        'high_jerk_count': 0,
      });
      expect(back.startTime, local);
      expect(back.startTime.isUtc, isFalse);
    });

    test('a legacy string with no offset reads as device-local', () {
      final e = RideModel.fromMap({
        'id': 'r',
        'user_id': 'u',
        'bike_id': 'b',
        'start_time': '2026-10-14T07:30:00.000',
        'distance_m': 0,
        'hard_brake_count': 0,
        'rapid_accel_count': 0,
        'high_jerk_count': 0,
        'status': 'completed',
      });
      expect(e.startTime, DateTime(2026, 10, 14, 7, 30));
    });
  });

  group('day ranges for a rider who changes time zone', () {
    setUp(() async {
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      // 19:30 UTC on 13 Oct: 01:30 on the 14th in Dhaka (+6), 23:30 on the
      // 13th in Dubai (+4). Recorded in Dhaka, viewed after flying to Dubai.
      await db.insert('rides', {
        'id': 'late',
        'user_id': 'u',
        'bike_id': 'b',
        'start_time': DateTime.utc(2026, 10, 13, 19, 30).toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.utc(2026, 10, 13, 19, 30).toIso8601String(),
      });
    });

    // A local day as the phone computes it: local midnight to midnight,
    // here written as UTC instants for a fixed offset.
    Future<List<String>> ridesOn(int day, {required int offsetHours}) async {
      final from =
          DateTime.utc(2026, 10, day).subtract(Duration(hours: offsetHours));
      final rows = await RideDao()
          .getCompletedBetween('u', from, from.add(const Duration(days: 1)));
      return [for (final r in rows) r['id'] as String];
    }

    test('in Dhaka the ride is on the 14th', () async {
      expect(await ridesOn(14, offsetHours: 6), ['late']);
      expect(await ridesOn(13, offsetHours: 6), isEmpty);
    });

    test('in Dubai the same ride is on the 13th', () async {
      expect(await ridesOn(13, offsetHours: 4), ['late']);
      expect(await ridesOn(14, offsetHours: 4), isEmpty);
    });

    test('local DateTime bounds are compared as UTC', () async {
      final ride = DateTime.utc(2026, 10, 13, 19, 30).toLocal();
      final from = DateTime(ride.year, ride.month, ride.day);
      final rows = await RideDao()
          .getCompletedBetween('u', from, from.add(const Duration(days: 1)));
      expect(rows.map((r) => r['id']), ['late']);
    });
  });
}
