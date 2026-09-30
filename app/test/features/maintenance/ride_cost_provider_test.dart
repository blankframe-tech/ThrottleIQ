@Timeout(Duration(seconds: 20))
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/maintenance_settings_section.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  sqfliteFfiInit();

  group('rideCostProvider (real SQLite)', () {
    late Database db;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u1',
        'brand': 'Yamaha',
        'model': 'FZ',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    tearDown(() async {
      DatabaseHelper.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('combines fuel settings, typical costs and logged costs', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      const key = (bikeId: 'b1', distanceKm: 10.0);
      // Keep the family alive while its sources load.
      final sub = c.listen(rideCostProvider(key), (_, __) {});
      addTearDown(sub.close);

      await c.read(bikeRunningCostProvider('b1').notifier)
          .save(fuelPricePerLitre: 130, kmPerLitre: 40); // 3.25/km

      final configs = await c.read(maintenanceConfigProvider('b1').future);
      final chain = configs.firstWhere((x) => x.serviceType == ServiceType.chain);
      await c.read(maintenanceConfigProvider('b1').notifier)
          .updateSingleConfig(chain.copyWith(typicalCost: 300)); // 300/600 = .5

      // Oil has a typical cost but a logged actual cost wins.
      final oil =
          configs.firstWhere((x) => x.serviceType == ServiceType.oilChange);
      await c.read(maintenanceConfigProvider('b1').notifier)
          .updateSingleConfig(oil.copyWith(typicalCost: 9999));
      await c.read(maintenanceProvider('b1').notifier).addLog(
            bikeId: 'b1',
            serviceType: ServiceType.oilChange,
            date: DateTime.now(),
            odometerKm: 1000,
            cost: 1500, // 1500/1500 = 1/km
          );

      await c.read(maintenanceConfigProvider('b1').future);
      await c.read(maintenanceProvider('b1').future);
      await c.read(bikeRunningCostProvider('b1').future);

      final b = c.read(rideCostProvider(key))!;
      final byType = {for (final l in b.lines) l.serviceType: l};
      expect(byType[ServiceType.fuel]!.cost, closeTo(32.5, 1e-9));
      expect(byType[ServiceType.oilChange]!.source, CostSource.history);
      expect(byType[ServiceType.oilChange]!.cost, closeTo(10, 1e-9));
      expect(byType[ServiceType.chain]!.cost, closeTo(5, 1e-9));
      expect(b.total, closeTo(47.5, 1e-9));

      // Persisted: a fresh container reads the same fuel settings back.
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final running = await c2.read(bikeRunningCostProvider('b1').future);
      expect(running.fuelPricePerLitre, 130);
      expect(running.kmPerLitre, 40);
    });
  });

  testWidgets('settings section lists every configuration action',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bike = BikeEntity(
      id: 'b1',
      userId: 'u1',
      brand: 'Yamaha',
      model: 'FZ',
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rideCostProvider.overrideWith((ref, key) => null),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(
              child: MaintenanceSettingsSection(bike: bike)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('MAINTENANCE SETTINGS'), findsOneWidget);
    expect(find.text('Running costs'), findsOneWidget);
    expect(find.text('Customize checks'), findsOneWidget);
    expect(find.text('Sync odometer'), findsOneWidget);
    expect(find.text('Reset service log'), findsOneWidget);
    expect(find.text('Distance units'), findsOneWidget);

    // km/mi toggle persists through the provider.
    await tester.tap(find.text('mi'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('maintenance_imperial_units'), isTrue);
  });
}
