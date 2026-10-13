@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_running_cost_dao.dart';
import 'package:throttleiq/core/database/daos/maintenance_config_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/maintenance/data/models/bike_running_cost_model.dart';
import 'package:throttleiq/features/maintenance/data/models/maintenance_config_model.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

/// Schema v18: per-check typical cost + per-bike fuel price & mileage.
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

  Future<void> createV17Tables() async {
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
      CREATE TABLE bike_maintenance_configs (
        bike_id TEXT NOT NULL,
        service_type TEXT NOT NULL,
        interval_km REAL NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        PRIMARY KEY (bike_id, service_type),
        FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
      )
    ''');
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<Set<String>> configColumns() async =>
      (await db.rawQuery('PRAGMA table_info(bike_maintenance_configs)'))
          .map((r) => r['name'] as String)
          .toSet();

  test('v17 → v18 adds typical_cost and bike_running_costs, keeps configs',
      () async {
    await createV17Tables();
    await db.insert('bike_maintenance_configs', {
      'bike_id': 'b1',
      'service_type': 'oilChange',
      'interval_km': 1500.0,
      'is_enabled': 1,
      'notes': 'Motul',
    });

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 17, 18);
    // Re-running must be survivable.
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 17, 18);

    expect(await configColumns(), contains('typical_cost'));
    final rows = await db.query('bike_maintenance_configs');
    expect(rows.single['notes'], 'Motul');
    expect(rows.single['typical_cost'], isNull);

    final tables = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, contains('bike_running_costs'));
  });

  test('fresh schema: typical cost and running costs round-trip via DAOs',
      () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    const cfg = MaintenanceConfigEntity(
      bikeId: 'b1',
      serviceType: ServiceType.oilChange,
      intervalKm: 1500,
      typicalCost: 950,
    );
    await MaintenanceConfigDao()
        .saveConfigsForBike('b1', [MaintenanceConfigModel.toMap(cfg)]);
    final back = (await MaintenanceConfigDao().getConfigsForBike('b1'))
        .map(MaintenanceConfigModel.fromMap)
        .single;
    expect(back, cfg);

    final dao = BikeRunningCostDao();
    expect(await dao.getForBike('b1'), isNull);
    const running = BikeRunningCostEntity(
        bikeId: 'b1', fuelPricePerLitre: 125, kmPerLitre: 45);
    await dao.upsert(BikeRunningCostModel.toMap(running));
    await dao.upsert(BikeRunningCostModel.toMap(running)); // upsert, no dup
    expect(BikeRunningCostModel.fromMap((await dao.getForBike('b1'))!),
        running);

    // Deleting the bike cascades its running costs.
    await db.delete('bikes', where: 'id = ?', whereArgs: ['b1']);
    expect(await dao.getForBike('b1'), isNull);
  });
}
