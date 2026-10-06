@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/maintenance/data/models/maintenance_config_model.dart';
import 'package:throttleiq/features/maintenance/data/models/maintenance_model.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

/// Schema v20 (issues §95): visits, km-or-time intervals, baselines, setup
/// profiles, paperwork, quick-check issues, log tombstones, odometer credits.
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

  Future<void> createV19Tables() async {
    await db.execute('''
      CREATE TABLE bikes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
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
    await db.execute('''
      CREATE TABLE bike_maintenance_configs (
        bike_id TEXT NOT NULL,
        service_type TEXT NOT NULL,
        interval_km REAL NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        typical_cost REAL,
        PRIMARY KEY (bike_id, service_type),
        FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
      )
    ''');
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar 150',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<Set<String>> columns(String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((r) => r['name'] as String)
          .toSet();

  test('v19 → v20 adds visit and interval columns, keeps data, re-runs', () async {
    await createV19Tables();
    await db.insert('maintenance_logs', {
      'id': 'l1',
      'bike_id': 'b1',
      'service_type': 'oilChange',
      'date': DateTime(2026, 5, 1).toIso8601String(),
      'odometer_km': 4200.0,
      'cost': 600.0,
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
    });
    await db.insert('bike_maintenance_configs', {
      'bike_id': 'b1',
      'service_type': 'oilChange',
      'interval_km': 1800.0,
      'is_enabled': 1,
    });
    await db.insert('bike_maintenance_configs', {
      'bike_id': 'b1',
      'service_type': 'frontDiscPads',
      'interval_km': 12000.0,
      'is_enabled': 1,
    });

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 19, 20);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 19, 20);

    expect(
        await columns('maintenance_logs'),
        containsAll(<String>[
          'visit_id', 'check_key', 'shop_name', 'shop_kind', 'receipt_path',
          'visit_total', 'visit_label', 'part_brand', 'part_grade',
        ]));
    expect(
        await columns('bike_maintenance_configs'),
        containsAll(<String>[
          'interval_days', 'warn_km', 'warn_days', 'baseline_km',
          'baseline_date', 'source', 'custom_label',
        ]));
    for (final t in [
      'deleted_maintenance_logs',
      'bike_maintenance_profiles',
      'bike_paperwork',
      'precheck_issues',
      'detection_odometer_credits',
    ]) {
      expect(await columns(t), isNotEmpty, reason: t);
    }

    // The old log reads back as a visit of one.
    final log = MaintenanceModel.fromMap(
        (await db.query('maintenance_logs')).single);
    expect(log.visitKey, 'l1');
    expect(log.cost, 600);

    // Existing intervals are the rider's own and gain their type's time
    // limit; km-only types stay km-only.
    final configs = (await db.query('bike_maintenance_configs'))
        .map(MaintenanceConfigModel.fromMap)
        .toList();
    final oil = configs.firstWhere((c) => c.serviceType == ServiceType.oilChange);
    expect(oil.intervalKm, 1800);
    expect(oil.intervalDays, 180);
    expect(oil.source, IntervalSource.user);
    final pads =
        configs.firstWhere((c) => c.serviceType == ServiceType.frontDiscPads);
    expect(pads.intervalDays, isNull);
  });

  test('fresh install schema matches the upgraded one', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    expect(await columns('maintenance_logs'), contains('visit_id'));
    expect(await columns('bike_maintenance_configs'), contains('interval_days'));
    expect(await columns('bike_maintenance_profiles'), contains('template_id'));
  });

  test('custom checks round-trip through the config table key', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Honda',
      'model': 'Hornet',
      'created_at': DateTime(2026).toIso8601String(),
    });
    const custom = MaintenanceConfigEntity(
      bikeId: 'b1',
      serviceType: ServiceType.custom,
      customId: 'abc',
      customLabel: 'Steering bearings',
      intervalKm: 0,
      intervalDays: 365,
      source: IntervalSource.user,
    );
    await db.insert(
        'bike_maintenance_configs', MaintenanceConfigModel.toMap(custom));
    final back = MaintenanceConfigModel.fromMap(
        (await db.query('bike_maintenance_configs')).single);
    expect(back, custom);
    expect(back.key, 'custom:abc');
  });
}
