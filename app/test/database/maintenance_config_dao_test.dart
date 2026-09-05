import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/maintenance_config_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/data/models/maintenance_config_model.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late MaintenanceConfigDao dao;
  late BikeDao bikeDao;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    dao = MaintenanceConfigDao();
    bikeDao = BikeDao();

    // Insert a parent bike for foreign key constraints
    await db.insert('bikes', {
      'id': 'bike-123',
      'user_id': 'user-1',
      'brand': 'Yamaha',
      'model': 'MT-07',
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('hasCustomized returns false initially, then true after saving', () async {
    expect(await dao.hasCustomized('bike-123'), isFalse);

    final configs = [
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.oilChange,
        intervalKm: 2500,
        isEnabled: true,
      )),
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.chain,
        intervalKm: 500,
        isEnabled: false,
      )),
    ];

    await dao.saveConfigsForBike('bike-123', configs);
    expect(await dao.hasCustomized('bike-123'), isTrue);

    final retrieved = await dao.getConfigsForBike('bike-123');
    expect(retrieved, hasLength(2));

    final entities = retrieved.map(MaintenanceConfigModel.fromMap).toList();
    expect(entities.first.serviceType, ServiceType.oilChange);
    expect(entities.first.intervalKm, 2500);
    expect(entities.first.isEnabled, isTrue);

    expect(entities.last.serviceType, ServiceType.chain);
    expect(entities.last.intervalKm, 500);
    expect(entities.last.isEnabled, isFalse);
  });

  test('saveConfigsForBike replaces previous configurations atomically', () async {
    final initial = [
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.oilChange,
        intervalKm: 1500,
        isEnabled: true,
      )),
    ];
    await dao.saveConfigsForBike('bike-123', initial);
    expect(await dao.getConfigsForBike('bike-123'), hasLength(1));

    // Overwrite with 3 different configs
    final updated = [
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.tire,
        intervalKm: 4000,
        isEnabled: true,
      )),
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.sparkPlug,
        intervalKm: 10000,
        isEnabled: true,
      )),
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.airFilter,
        intervalKm: 8000,
        isEnabled: false,
      )),
    ];
    await dao.saveConfigsForBike('bike-123', updated);

    final rows = await dao.getConfigsForBike('bike-123');
    expect(rows, hasLength(3));
    final types = rows.map((r) => r['service_type']).toSet();
    expect(types, containsAll(['tire', 'sparkPlug', 'airFilter']));
    expect(types, isNot(contains('oilChange')));
  });

  test('deleting bike cascades and deletes its maintenance configs', () async {
    final configs = [
      MaintenanceConfigModel.toMap(const MaintenanceConfigEntity(
        bikeId: 'bike-123',
        serviceType: ServiceType.oilChange,
        intervalKm: 1500,
        isEnabled: true,
      )),
    ];
    await dao.saveConfigsForBike('bike-123', configs);
    expect(await dao.hasCustomized('bike-123'), isTrue);

    await bikeDao.delete('bike-123');

    expect(await dao.hasCustomized('bike-123'), isFalse);
    expect(await dao.getConfigsForBike('bike-123'), isEmpty);
  });
}
