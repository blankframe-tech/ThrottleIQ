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
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/add_maintenance_log_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/check_detail_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/maintenance_setup_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/maintenance_check_row.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Renders the redesigned page end to end from fixed data: hero, strip,
/// urgency groups, quick check, visit history, money and papers — catching
/// layout overflows and wiring mistakes no unit test sees.
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

  MaintenanceEntity log(String id, ServiceType t, double km, int daysAgo,
          {String? visit, double? total, String? shop}) =>
      MaintenanceEntity(
        id: id,
        bikeId: 'b1',
        serviceType: t,
        date: now.subtract(Duration(days: daysAgo)),
        odometerKm: km,
        createdAt: now,
        visitId: visit,
        visitTotal: total,
        shopName: shop,
      );

  final logs = [
    log('1', ServiceType.oilChange, 12100, 40,
        visit: 'v1', total: 1400, shop: 'Rahim Motors'),
    log('2', ServiceType.chain, 12100, 40, visit: 'v1', total: 1400),
    log('3', ServiceType.airFilter, 12100, 40, visit: 'v1', total: 1400),
    log('4', ServiceType.tire, 9000, 200),
  ];
  final configs = configsFromTemplate(
      bikeId: 'b1', template: templateById('bajaj_pulsar_150'));

  Future<void> pump(WidgetTester tester,
      {required bool onboarded, Widget? screen}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => screen ?? const MaintenanceScreen(bikeId: 'b1')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        garageProvider.overrideWith(() => _Garage([bike])),
        maintenanceProvider.overrideWith(() => _Logs(logs)),
        maintenanceConfigProvider.overrideWith(() => _Configs(configs)),
        maintenanceProfileProvider.overrideWith(() => _Profile(onboarded
            ? MaintenanceProfileEntity(
                bikeId: 'b1',
                templateId: 'bajaj_pulsar_150',
                ridingProfile: RidingProfile.severe,
                onboardedAt: now,
              )
            : null)),
        isMaintenanceCustomizedProvider.overrideWith((ref, id) async => onboarded),
        bikeUsageProvider.overrideWith((ref, id) async => const BikeUsage(
            UsageStats(
              avgDailyKm: 30,
              rideDistanceKm: 900,
              movingSeconds: 60000,
              durationSeconds: 100000,
            ),
            0)),
        paperworkProvider.overrideWith(() => _Papers([
              PaperworkEntity(
                bikeId: 'b1',
                kind: PaperworkKind.taxToken,
                expiresOn: now.add(const Duration(days: 12)),
              ),
            ])),
        precheckIssuesProvider.overrideWith(() => _Issues([
              PrecheckIssue(
                id: 'p1',
                bikeId: 'b1',
                item: PrecheckItem.chain,
                createdAt: now,
              ),
            ])),
        maintenanceMoneyProvider.overrideWith((ref, id) async =>
            computeMoney(logs: logs, now: now, distanceKm12m: 3000)),
        canOrderPartsProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('bn')],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the forecast page for a set-up bike', (tester) async {
    await pump(tester, onboarded: true);
    expect(tester.takeException(), isNull);

    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.byKey(const Key('heroDoneIt')), findsOneWidget);
    expect(find.textContaining('NEEDS ATTENTION'), findsOneWidget); // labels are upper-cased
    expect(find.text('Chain'), findsWidgets); // quick-check issue row
    expect(find.text('Service visit'), findsOneWidget); // 3-item visit
    expect(find.text('Rahim Motors', findRichText: true), findsNothing);
    expect(find.textContaining('Tax token'), findsOneWidget);
    expect(find.byKey(const Key('logVisitFab')), findsOneWidget);
    expect(find.byKey(const Key('maintenanceSetupCard')), findsNothing);
    // Severe roads shortened the air filter, and the row says so.
    expect(find.textContaining('Dusty or wet roads'), findsWidgets);
  });

  testWidgets('log a visit: due items pre-ticked, bundles, oil details', (tester) async {
    await pump(tester,
        onboarded: true,
        screen: const AddMaintenanceLogScreen(bikeId: 'b1'));
    expect(tester.takeException(), isNull);
    expect(find.text('Log a visit'), findsOneWidget);
    expect(find.text('General servicing'), findsOneWidget);
    expect(find.byKey(const Key('visitSave')), findsOneWidget);
    // Tick oil via its bundle: the oil details appear.
    await tester.tap(find.text('Oil change').first);
    await tester.pumpAndSettle();
    expect(find.text('ENGINE OIL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup screen renders the suggested schedule', (tester) async {
    await pump(tester,
        onboarded: false, screen: const MaintenanceSetupScreen(bikeId: 'b1'));
    expect(tester.takeException(), isNull);
    expect(find.text('Bajaj Pulsar 150'), findsWidgets); // bike + schedule
    expect(find.text('FROM THE MANUAL'), findsOneWidget); // pills are upper-cased
    expect(find.byKey(const Key('setupSave')), findsOneWidget);
  });

  testWidgets('part detail renders history and interval source', (tester) async {
    await pump(tester,
        onboarded: true,
        screen: const CheckDetailScreen(bikeId: 'b1', checkKey: 'oilChange'));
    expect(tester.takeException(), isNull);
    expect(find.text('From your bike\'s schedule'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
  });

  testWidgets('a bike that was never set up gets the setup card', (tester) async {
    await pump(tester, onboarded: false);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('maintenanceSetupCard')), findsOneWidget);
  });
}

class _Garage extends GarageNotifier {
  _Garage(this._bikes);
  final List<BikeEntity> _bikes;
  @override
  Future<List<BikeEntity>> build() async => _bikes;
}

class _Logs extends MaintenanceNotifier {
  _Logs(this._logs);
  final List<MaintenanceEntity> _logs;
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async => _logs;
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

class _Papers extends PaperworkNotifier {
  _Papers(this._p);
  final List<PaperworkEntity> _p;
  @override
  Future<List<PaperworkEntity>> build(String bikeId) async => _p;
}

class _Issues extends PrecheckIssuesNotifier {
  _Issues(this._i);
  final List<PrecheckIssue> _i;
  @override
  Future<List<PrecheckIssue>> build(String bikeId) async => _i;
}
