import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_money.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/catalog/schedule_templates.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_profile.dart';
import 'package:throttleiq/features/maintenance/domain/entities/service_visit.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/add_maintenance_log_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/maintenance_check_row.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R2: the visit form rejects negative / NaN / Infinity numbers,
/// and a save that throws re-enables the button instead of leaving it stuck.
void main() {
  final now = DateTime.now();
  final bike = BikeEntity(
    id: 'b1',
    userId: 'u1',
    brand: 'Bajaj',
    model: 'Pulsar 150',
    odometerKm: 12000,
    totalDistanceM: 1500 * 1000,
    createdAt: DateTime(2025, 1, 1),
  );
  final configs = configsFromTemplate(
      bikeId: 'b1', template: templateById('bajaj_pulsar_150'));

  late _Logs logsNotifier;

  Future<void> pump(WidgetTester tester, {bool throwOnSave = false}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    logsNotifier = _Logs(throwOnSave: throwOnSave);

    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const AddMaintenanceLogScreen(bikeId: 'b1')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        garageProvider.overrideWith(() => _Garage([bike])),
        maintenanceProvider.overrideWith(() => logsNotifier),
        maintenanceConfigProvider.overrideWith(() => _Configs(configs)),
        maintenanceProfileProvider.overrideWith(() => _Profile(
            MaintenanceProfileEntity(
              bikeId: 'b1',
              templateId: 'bajaj_pulsar_150',
              ridingProfile: RidingProfile.severe,
              onboardedAt: now,
            ))),
        isMaintenanceCustomizedProvider.overrideWith((ref, id) async => true),
        bikeUsageProvider.overrideWith((ref, id) async => const BikeUsage(
            UsageStats(
              avgDailyKm: 30,
              rideDistanceKm: 900,
              movingSeconds: 60000,
              durationSeconds: 100000,
            ),
            0)),
        maintenanceMoneyProvider.overrideWith((ref, id) async =>
            computeMoney(logs: const [], now: now, distanceKm12m: 3000)),
        canOrderPartsProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const Key('visitSave'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('odometer rejects negative, NaN and Infinity; nothing saved',
      (tester) async {
    await pump(tester);
    // Make sure at least one job is ticked.
    await tester.tap(find.text('Oil change').first);
    await tester.pumpAndSettle();
    for (final bad in ['-5', 'NaN', 'Infinity']) {
      await tester.enterText(find.byKey(const Key('visitOdometer')), bad);
      await tapSave(tester);
      expect(find.text('Invalid number'), findsWidgets, reason: bad);
    }
    expect(logsNotifier.saveCalls, 0);
  });

  testWidgets('a negative cost is rejected', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Oil change').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('visitOdometer')), '12500');
    await tester.enterText(find.byKey(const Key('visitCost')), '-100');
    await tapSave(tester);
    expect(find.text('Invalid number'), findsWidgets);
    expect(logsNotifier.saveCalls, 0);
  });

  testWidgets('a throwing save re-enables the button and tells the rider',
      (tester) async {
    await pump(tester, throwOnSave: true);
    await tester.tap(find.text('Oil change').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('visitOdometer')), '12500');
    await tapSave(tester);

    expect(logsNotifier.saveCalls, 1);
    expect(find.text("Couldn't save the visit. Please try again."),
        findsOneWidget);
    final button =
        tester.widget<ElevatedButton>(find.byKey(const Key('visitSave')));
    expect(button.onPressed, isNotNull);
  });
}

class _Garage extends GarageNotifier {
  _Garage(this._bikes);
  final List<BikeEntity> _bikes;
  @override
  Future<List<BikeEntity>> build() async => _bikes;
}

class _Logs extends MaintenanceNotifier {
  _Logs({this.throwOnSave = false});
  final bool throwOnSave;
  int saveCalls = 0;
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async => const [];
  @override
  Future<String> saveVisit(VisitDraft draft) async {
    saveCalls++;
    if (throwOnSave) throw StateError('disk full');
    return 'v';
  }
}

class _Configs extends MaintenanceConfigNotifier {
  _Configs(this._configs);
  final List<MaintenanceConfigEntity> _configs;
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async => _configs;
}

class _Profile extends MaintenanceProfileNotifier {
  _Profile(this._p);
  final MaintenanceProfileEntity? _p;
  @override
  Future<MaintenanceProfileEntity?> build(String bikeId) async => _p;
}
