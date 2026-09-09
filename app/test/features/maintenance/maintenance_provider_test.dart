@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);

    // Insert bike for foreign key constraint
    await db.insert('bikes', {
      'id': 'bike-prov-1',
      'user_id': 'u1',
      'brand': 'Kawasaki',
      'model': 'Ninja 400',
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('loads recommended defaults including fuel with hasCustomized false', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final isCustomized = await container.read(isMaintenanceCustomizedProvider('bike-prov-1').future);
    expect(isCustomized, isFalse);

    final configs = await container.read(maintenanceConfigProvider('bike-prov-1').future);
    expect(configs, isNotEmpty);

    // Fuel item exists in defaults and is enabled
    final fuel = configs.firstWhere((c) => c.serviceType == ServiceType.fuel);
    expect(fuel.isEnabled, isTrue);
    expect(fuel.intervalKm, 300.0);
    expect(fuel.notes, isNull);

    // Engine oil exists in defaults
    final oil = configs.firstWhere((c) => c.serviceType == ServiceType.oilChange);
    expect(oil.isEnabled, isTrue);
    expect(oil.intervalKm, 1500.0);
  });

  test('updateSingleConfig modifies item and persists customized state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialIsCustomized = await container.read(isMaintenanceCustomizedProvider('bike-prov-1').future);
    expect(initialIsCustomized, isFalse);

    final initialConfigs = await container.read(maintenanceConfigProvider('bike-prov-1').future);
    final notifier = container.read(maintenanceConfigProvider('bike-prov-1').notifier);
    final oil = initialConfigs.firstWhere((c) => c.serviceType == ServiceType.oilChange);

    final updatedOil = oil.copyWith(
      intervalKm: 3500.0,
      notes: 'Motul 300V Factory Line 10W-40',
    );

    await notifier.updateSingleConfig(updatedOil);

    final updatedIsCustomized = await container.read(isMaintenanceCustomizedProvider('bike-prov-1').future);
    expect(updatedIsCustomized, isTrue);

    final updatedConfigs = await container.read(maintenanceConfigProvider('bike-prov-1').future);
    final currentOil = updatedConfigs.firstWhere((c) => c.serviceType == ServiceType.oilChange);
    expect(currentOil.intervalKm, 3500.0);
    expect(currentOil.notes, 'Motul 300V Factory Line 10W-40');

    // Reload from fresh container / DB to confirm persistence
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);

    final persisted = await container2.read(maintenanceConfigProvider('bike-prov-1').future);
    final persistedOil = persisted.firstWhere((c) => c.serviceType == ServiceType.oilChange);
    expect(persistedOil.intervalKm, 3500.0);
    expect(persistedOil.notes, 'Motul 300V Factory Line 10W-40');
  });

  test('saveConfigs saves entire configuration set atomically', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialConfigs = await container.read(maintenanceConfigProvider('bike-prov-1').future);
    final notifier = container.read(maintenanceConfigProvider('bike-prov-1').notifier);

    final modified = initialConfigs.map((c) {
      if (c.serviceType == ServiceType.fuel) {
        return c.copyWith(intervalKm: 320, notes: 'Octane 95');
      }
      return c;
    }).toList();

    await notifier.saveConfigs(modified);

    final isCustomized = await container.read(isMaintenanceCustomizedProvider('bike-prov-1').future);
    expect(isCustomized, isTrue);

    final currentConfigs = await container.read(maintenanceConfigProvider('bike-prov-1').future);
    final fuel = currentConfigs.firstWhere((c) => c.serviceType == ServiceType.fuel);
    expect(fuel.intervalKm, 320);
    expect(fuel.notes, 'Octane 95');
  });
}
