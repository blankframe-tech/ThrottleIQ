@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/maintenance_config_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/maintenance/data/models/maintenance_config_model.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

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

  /// Simulates a pre-existing v13 database with bike_maintenance_configs without notes column.
  Future<void> createV13Schema() async {
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
      CREATE TABLE bike_maintenance_configs (
        bike_id TEXT NOT NULL,
        service_type TEXT NOT NULL,
        interval_km REAL NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (bike_id, service_type),
        FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
      )
    ''');
  }

  test('v13 → v14 adds notes column and preserves existing configs', () async {
    await createV13Schema();
    await db.insert('bikes', {
      'id': 'bike-v13',
      'user_id': 'u1',
      'brand': 'Yamaha',
      'model': 'R15',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Seed v13 maintenance config (without notes column)
    await db.insert('bike_maintenance_configs', {
      'bike_id': 'bike-v13',
      'service_type': 'oilChange',
      'interval_km': 2500.0,
      'is_enabled': 1,
    });

    // Run migration 13 -> 14
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 13, 14);
    DatabaseHelper.overrideDatabaseForTesting(db);

    // Existing config preserved and notes column defaulted to null
    final dao = MaintenanceConfigDao();
    expect(await dao.hasCustomized('bike-v13'), isTrue);

    final configs = await dao.getConfigsForBike('bike-v13');
    expect(configs, hasLength(1));
    expect(configs.first['service_type'], 'oilChange');
    expect(configs.first['notes'], isNull);

    // Can now insert and update configs with custom notes
    await dao.saveConfigsForBike('bike-v13', [
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-v13',
        serviceType: ServiceType.oilChange,
        intervalKm: 2500.0,
        isEnabled: true,
        notes: 'Motul 7100 10W-40 4T Full Synthetic',
      )),
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-v13',
        serviceType: ServiceType.tire,
        intervalKm: 15000.0,
        isEnabled: true,
        notes: 'Front: 100/80-17 (DOT 2224), Rear: 140/70-R17 (DOT 2424)',
      )),
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-v13',
        serviceType: ServiceType.fuel,
        intervalKm: 300.0,
        isEnabled: true,
        notes: 'Octane 95, Tank capacity 11L',
      )),
    ]);

    final updated = await dao.getConfigsForBike('bike-v13');
    expect(updated, hasLength(3));

    final oil = updated.firstWhere((r) => r['service_type'] == 'oilChange');
    expect(oil['notes'], 'Motul 7100 10W-40 4T Full Synthetic');

    final tire = updated.firstWhere((r) => r['service_type'] == 'tire');
    expect(tire['notes'], 'Front: 100/80-17 (DOT 2224), Rear: 140/70-R17 (DOT 2424)');

    final fuel = updated.firstWhere((r) => r['service_type'] == 'fuel');
    expect(fuel['notes'], 'Octane 95, Tank capacity 11L');
  });

  test('v14 upgrade is idempotent when run repeatedly', () async {
    await createV13Schema();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 13, 14);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 13, 14);
    DatabaseHelper.overrideDatabaseForTesting(db);

    final dao = MaintenanceConfigDao();
    expect(await dao.hasCustomized('any-bike'), isFalse);
  });

  test('fresh v14 schema contains notes column and matches upgraded schema', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);

    await db.insert('bikes', {
      'id': 'fresh-bike',
      'user_id': 'u1',
      'brand': 'Suzuki',
      'model': 'Gixxer',
      'created_at': DateTime.now().toIso8601String(),
    });

    final dao = MaintenanceConfigDao();
    await dao.saveConfigsForBike('fresh-bike', [
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'fresh-bike',
        serviceType: ServiceType.fuel,
        intervalKm: 350.0,
        isEnabled: true,
        notes: 'Premium 95 Octane',
      )),
    ]);

    final rows = await dao.getConfigsForBike('fresh-bike');
    expect(rows, hasLength(1));
    expect(rows.first['notes'], 'Premium 95 Octane');
  });
}
