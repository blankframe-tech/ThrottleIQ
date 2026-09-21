@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

/// Schema v17 stamps a ride with the saved route it was recorded against
/// (issues §78.21).
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

  /// A `rides` table as it stood at v16 — no route columns.
  Future<void> createV16Rides() async {
    await db.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        bike_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        distance_m REAL NOT NULL DEFAULT 0,
        avg_speed_ms REAL,
        max_speed_ms REAL,
        duration_s INTEGER,
        moving_s INTEGER,
        hard_brake_count INTEGER NOT NULL DEFAULT 0,
        rapid_accel_count INTEGER NOT NULL DEFAULT 0,
        high_jerk_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        map_snapshot_path TEXT,
        is_auto INTEGER NOT NULL DEFAULT 0,
        bike_confidence TEXT NOT NULL DEFAULT 'high',
        synced INTEGER NOT NULL DEFAULT 0,
        track_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<Set<String>> rideColumns() async =>
      (await db.rawQuery('PRAGMA table_info(rides)'))
          .map((row) => row['name'] as String)
          .toSet();

  test('v16 → v17 adds the route columns and keeps existing rides', () async {
    await createV16Rides();
    await db.insert('rides', {
      'id': 'ride-before',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': DateTime(2026, 1, 1).toIso8601String(),
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 16, 17);

    expect(await rideColumns(), containsAll(['route_id', 'route_name']));

    final rows = await db.query('rides');
    expect(rows, hasLength(1));
    // An existing ride followed no route, and NULL is the truthful reading of
    // that — not a placeholder standing in for unknown.
    expect(rows.single['route_id'], isNull);
    expect(rows.single['route_name'], isNull);
  });

  test('the upgrade survives being run twice', () async {
    await createV16Rides();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 16, 17);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 16, 17);
    expect(await rideColumns(), containsAll(['route_id', 'route_name']));
  });

  test('a fresh schema has the same columns as the upgrade leg', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    expect(await rideColumns(), containsAll(['route_id', 'route_name']));
  });

  test('a route-followed ride round-trips through RideModel', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Yamaha',
      'model': 'R15',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    final ride = RideEntity(
      id: 'ride-1',
      userId: 'u1',
      bikeId: 'b1',
      startTime: DateTime(2026, 1, 1),
      routeId: 'route-9',
      routeName: 'Mirpur loop',
    );
    await db.insert('rides', RideModel.toMap(ride));

    final back = RideModel.fromMap((await db.query('rides')).single);
    expect(back.routeId, 'route-9');
    expect(back.routeName, 'Mirpur loop');
    expect(back.followedRoute, isTrue);
  });

  test('an ordinary ride reads back with no route', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Yamaha',
      'model': 'R15',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    await db.insert(
      'rides',
      RideModel.toMap(RideEntity(
        id: 'ride-2',
        userId: 'u1',
        bikeId: 'b1',
        startTime: DateTime(2026, 1, 1),
      )),
    );

    final back = RideModel.fromMap((await db.query('rides')).single);
    expect(back.routeId, isNull);
    expect(back.followedRoute, isFalse);
  });
}
