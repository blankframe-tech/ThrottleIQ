import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

/// Per-ride overspeed count (schema v25): counted per episode by the event
/// detector, persisted on the ride row, NULL on legacy rides.
void main() {
  sqfliteFfiInit();

  group('EventDetector.overspeedCount', () {
    test('counts episodes, not samples', () {
      final d = EventDetector(overspeedThresholdMs: 20);
      // One sustained excursion over the limit = 1.
      for (final s in [18.0, 21.0, 22.0, 23.0, 21.0]) {
        d.detect(accel: 0, jerk: 0, speedMs: s);
      }
      expect(d.overspeedCount, 1);
      // Hovering just under the limit (inside the re-arm band) doesn't
      // re-arm, so noise around the line is still one episode.
      for (final s in [19.5, 20.5, 19.6, 20.4]) {
        d.detect(accel: 0, jerk: 0, speedMs: s);
      }
      expect(d.overspeedCount, 1);
      // Dropping clearly below and speeding up again is a second episode.
      for (final s in [15.0, 25.0, 26.0]) {
        d.detect(accel: 0, jerk: 0, speedMs: s);
      }
      expect(d.overspeedCount, 2);
      d.reset();
      expect(d.overspeedCount, 0);
    });
  });

  group('RideModel', () {
    Map<String, dynamic> row({Object? overspeed = _absent}) => {
          'id': 'r',
          'user_id': 'u',
          'bike_id': 'b',
          'start_time': '2026-10-01T08:00:00.000',
          'distance_m': 1000.0,
          'hard_brake_count': 0,
          'rapid_accel_count': 0,
          'high_jerk_count': 0,
          'status': 'completed',
          if (overspeed != _absent) 'overspeed_count': overspeed,
        };

    test('legacy rows read as null, not 0', () {
      expect(RideModel.fromMap(row()).overspeedCount, isNull);
      expect(RideModel.fromMap(row(overspeed: null)).overspeedCount, isNull);
    });

    test('round-trips a counted ride', () {
      final e = RideModel.fromMap(row(overspeed: 3));
      expect(e.overspeedCount, 3);
      expect(RideModel.toMap(e)['overspeed_count'], 3);
      expect(e.copyWith(distanceM: 5).overspeedCount, 3);
    });
  });

  group('v25 migration', () {
    late Database db;
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    });
    tearDown(() => db.close());

    test('fresh schema has a nullable overspeed_count', () async {
      await DatabaseHelper.instance.createSchemaForTesting(db);
      final cols = await db.rawQuery('PRAGMA table_info(rides)');
      final col = cols.firstWhere((c) => c['name'] == 'overspeed_count');
      expect(col['notnull'], 0);
      expect(col['dflt_value'], isNull);
    });

    test('upgrade adds the column, leaves existing rides NULL, re-runnable',
        () async {
      await db.execute('''
        CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          bike_id TEXT NOT NULL, start_time TEXT NOT NULL,
          distance_m REAL NOT NULL DEFAULT 0,
          hard_brake_count INTEGER NOT NULL DEFAULT 0,
          rapid_accel_count INTEGER NOT NULL DEFAULT 0,
          high_jerk_count INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'active', created_at TEXT NOT NULL)
      ''');
      await db.insert('rides', {
        'id': 'old',
        'user_id': 'u',
        'bike_id': 'b',
        'start_time': '2026-01-01',
        'status': 'completed',
        'created_at': '2026-01-01',
      });
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 24, 25);
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 24, 25);
      final r = (await db.query('rides')).single;
      expect(r.containsKey('overspeed_count'), isTrue);
      expect(r['overspeed_count'], isNull);
      expect(RideModel.fromMap(r).overspeedCount, isNull);
    });
  });

  test('ridePayload drops a NULL overspeed_count but keeps a real one', () {
    expect(CloudRepository.ridePayload({'id': 'r', 'overspeed_count': null}),
        isNot(contains('overspeed_count')));
    expect(CloudRepository.ridePayload({'id': 'r', 'overspeed_count': 0}),
        containsPair('overspeed_count', 0));
  });

  test('a new RideEntity defaults to unknown', () {
    final e = RideEntity(
        id: 'r', userId: 'u', bikeId: 'b', startTime: DateTime(2026));
    expect(e.overspeedCount, isNull);
  });
}

const _absent = Object();
