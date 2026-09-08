@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/maintenance_config_dao.dart';
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

  /// Simulates a pre-existing v12 database with stored bikes and rides.
  Future<void> createV12Schema() async {
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
        odometer_km REAL,
        color_value INTEGER,
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
        moving_s INTEGER,
        hard_brake_count INTEGER NOT NULL DEFAULT 0,
        rapid_accel_count INTEGER NOT NULL DEFAULT 0,
        high_jerk_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        map_snapshot_path TEXT,
        is_auto INTEGER NOT NULL DEFAULT 0,
        bike_confidence TEXT NOT NULL DEFAULT 'high',
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_logs (
        id TEXT PRIMARY KEY,
        bike_id TEXT NOT NULL,
        service_type TEXT NOT NULL,
        date TEXT NOT NULL,
        odometer_km REAL NOT NULL,
        cost REAL,
        notes TEXT,
        custom_label TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  test('v12 → v13 creates bike_maintenance_configs and keeps existing bikes', () async {
    await createV12Schema();
    await db.insert('bikes', {
      'id': 'bike-pre-upgrade',
      'user_id': 'u1',
      'brand': 'Honda',
      'model': 'CBR650R',
      'created_at': DateTime.now().toIso8601String(),
    });

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 12, 13);
    DatabaseHelper.overrideDatabaseForTesting(db);

    // Existing bike data is preserved
    final bikes = await db.query('bikes');
    expect(bikes, hasLength(1));
    expect(bikes.single['id'], 'bike-pre-upgrade');

    // New bike_maintenance_configs table is immediately functional
    final dao = MaintenanceConfigDao();
    expect(await dao.hasCustomized('bike-pre-upgrade'), isFalse);

    await dao.saveConfigsForBike('bike-pre-upgrade', [
      {
        'bike_id': 'bike-pre-upgrade',
        'service_type': 'oilChange',
        'interval_km': 1500,
        'is_enabled': 1,
      }
    ]);

    expect(await dao.hasCustomized('bike-pre-upgrade'), isTrue);
    final rows = await dao.getConfigsForBike('bike-pre-upgrade');
    expect(rows, hasLength(1));
  });

  test('v13 upgrade is idempotent when run multiple times', () async {
    await createV12Schema();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 12, 13);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 12, 13);
    DatabaseHelper.overrideDatabaseForTesting(db);

    final dao = MaintenanceConfigDao();
    expect(await dao.hasCustomized('any-bike'), isFalse);
  });

  test('fresh v13 schema matches upgrade leg', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);

    final dao = MaintenanceConfigDao();
    expect(await dao.hasCustomized('any-bike'), isFalse);
  });
}
