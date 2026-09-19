@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
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

  group('resetItems (master service log reset)', () {
    test('logs each ticked service type as serviced now at the given odometer', () async {
      final bike = BikeEntity(
        id: 'bike-prov-1',
        userId: 'u1',
        brand: 'Kawasaki',
        model: 'Ninja 400',
        odometerKm: 5000,
        createdAt: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          garageProvider.overrideWith(() => _FakeGarageNotifier([bike])),
        ],
      );
      addTearDown(container.dispose);

      // Seed an old log so we can confirm reset adds a new entry rather than
      // mutating history.
      await container.read(maintenanceProvider('bike-prov-1').notifier).addLog(
            bikeId: 'bike-prov-1',
            serviceType: ServiceType.oilChange,
            date: DateTime(2026, 1, 1),
            odometerKm: 1000,
          );

      final notifier = container.read(maintenanceProvider('bike-prov-1').notifier);
      await notifier.resetItems(
        [ServiceType.oilChange, ServiceType.chain],
        odometerKm: 5000,
      );

      final logs = await container.read(maintenanceProvider('bike-prov-1').future);
      expect(logs, hasLength(3)); // original oil log + 2 new reset logs

      final oilLogs = logs.where((l) => l.serviceType == ServiceType.oilChange).toList();
      expect(oilLogs, hasLength(2)); // history kept, not overwritten
      expect(oilLogs.any((l) => l.odometerKm == 1000), isTrue);
      expect(oilLogs.any((l) => l.odometerKm == 5000), isTrue);

      final chainLogs = logs.where((l) => l.serviceType == ServiceType.chain).toList();
      expect(chainLogs, hasLength(1));
      expect(chainLogs.single.odometerKm, 5000);

      // Resetting resolves each item's reminder back to freshly-serviced.
      // Force the async providers it derives from to resolve first, or the
      // synchronous reminders provider sees them as still loading and falls
      // back to empty lists.
      await container.read(maintenanceConfigProvider('bike-prov-1').future);
      await container.read(garageProvider.future);
      final reminders = container.read(maintenanceRemindersProvider('bike-prov-1'));
      final oilReminder = reminders.firstWhere((r) => r.serviceType == ServiceType.oilChange);
      expect(oilReminder.kmSinceService, 0);
    });

    test('does nothing when no items are selected', () async {
      final container = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(maintenanceProvider('bike-prov-1').notifier);
      await notifier.resetItems([], odometerKm: 5000);

      final logs = await container.read(maintenanceProvider('bike-prov-1').future);
      expect(logs, isEmpty);
    });
  });
}

class _FakeGarageNotifier extends GarageNotifier {
  _FakeGarageNotifier(this._bikes);
  final List<BikeEntity> _bikes;

  @override
  Future<List<BikeEntity>> build() async => _bikes;
}
