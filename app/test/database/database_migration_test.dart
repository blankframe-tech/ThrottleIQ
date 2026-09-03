@Timeout(Duration(seconds: 30))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> createV1Schema() async {
    await db.execute('''
      CREATE TABLE bikes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER,
        cc INTEGER,
        image_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        total_distance_m REAL NOT NULL DEFAULT 0,
        ride_count INTEGER NOT NULL DEFAULT 0,
        last_ride_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

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
        hard_brake_count INTEGER NOT NULL DEFAULT 0,
        rapid_accel_count INTEGER NOT NULL DEFAULT 0,
        high_jerk_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        map_snapshot_path TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ride_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        speed_ms REAL NOT NULL,
        acceleration REAL,
        jerk REAL,
        altitude_m REAL,
        FOREIGN KEY(ride_id) REFERENCES rides(id)
      )
    ''');
  }

  Future<List<String>> getTableColumns(String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.map((r) => r['name'] as String).toList();
  }

  Future<List<String>> getAllTables() async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    return tables.map((r) => r['name'] as String).toList();
  }

  test('full migration ladder: v1 -> v12 upgrades all tables and columns', () async {
    await createV1Schema();

    // Insert baseline data at v1
    await db.insert('bikes', {
      'id': 'bike-v1',
      'user_id': 'user-1',
      'brand': 'Yamaha',
      'model': 'MT-03',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    await db.insert('rides', {
      'id': 'ride-v1',
      'user_id': 'user-1',
      'bike_id': 'bike-v1',
      'start_time': DateTime(2026, 1, 1, 10).toIso8601String(),
      'created_at': DateTime(2026, 1, 1, 10).toIso8601String(),
    });

    await db.insert('ride_points', {
      'ride_id': 'ride-v1',
      'timestamp': DateTime(2026, 1, 1, 10).toIso8601String(),
      'lat': 23.8103,
      'lng': 90.4125,
      'speed_ms': 12.5,
    });

    // Run the full upgrade ladder
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 1, 12);
    DatabaseHelper.overrideDatabaseForTesting(db);

    // Verify all expected tables now exist
    final tables = await getAllTables();
    expect(tables, containsAll([
      'bikes',
      'rides',
      'ride_points',
      'maintenance_logs',
      'user_profiles',
      'deleted_bikes',
      'outbox',
      'auto_detections',
      'auto_fixes',
    ]));

    // Verify newly added columns on bikes
    final bikeColumns = await getTableColumns('bikes');
    expect(bikeColumns, containsAll(['odometer_km', 'color_value']));

    // Verify newly added columns on rides
    final rideColumns = await getTableColumns('rides');
    expect(rideColumns, containsAll(['moving_s', 'is_auto', 'bike_confidence']));

    // Verify newly added columns on ride_points
    final pointColumns = await getTableColumns('ride_points');
    expect(pointColumns, containsAll([
      'period_type',
      'accuracy_m',
      'heading_deg',
      'confidence',
      'imu_quality',
      'is_cornering',
    ]));

    // Verify existing v1 data survived intact
    final bikes = await db.query('bikes');
    expect(bikes.length, 1);
    expect(bikes.first['id'], 'bike-v1');

    final rides = await db.query('rides');
    expect(rides.length, 1);
    expect(rides.first['id'], 'ride-v1');
    expect(rides.first['is_auto'], 0);
    expect(rides.first['bike_confidence'], 'high');

    final points = await db.query('ride_points');
    expect(points.length, 1);
    expect(points.first['ride_id'], 'ride-v1');
    expect(points.first['period_type'], 'moving');
  });

  test('partial migration: v8 -> v12 adds outbox, auto-tracking and bike color', () async {
    await createV1Schema();
    // Simulate v8 state by running 1 -> 8
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 1, 8);

    // Now run 8 -> 12
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 8, 12);

    final tables = await getAllTables();
    expect(tables, containsAll(['outbox', 'auto_detections', 'auto_fixes']));

    final bikeColumns = await getTableColumns('bikes');
    expect(bikeColumns, contains('color_value'));

    final rideColumns = await getTableColumns('rides');
    expect(rideColumns, containsAll(['moving_s', 'is_auto', 'bike_confidence']));
  });

  test('migration is idempotent when run on v11 -> v12', () async {
    await createV1Schema();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 1, 11);

    // v11 -> v12 uses _addColumnIfMissing and is safe to re-run
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 11, 12);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 11, 12);

    final tables = await getAllTables();
    expect(tables, contains('bikes'));
    expect(tables, contains('rides'));
    final bikeColumns = await getTableColumns('bikes');
    expect(bikeColumns, contains('color_value'));
  });

  test('full ladder migration is idempotent when run repeatedly', () async {
    await createV1Schema();

    // Run ladder once
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 1, 12);

    // Run ladder again immediately — must not throw or fail on existing columns
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 1, 12);

    final tables = await getAllTables();
    expect(tables, contains('bikes'));
    expect(tables, contains('rides'));
  });
}
