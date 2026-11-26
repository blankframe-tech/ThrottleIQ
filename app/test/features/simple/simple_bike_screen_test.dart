import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_profile.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/fuel_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/forecast_text.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/paperwork_card.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/quick_service_sheet.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_provider.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_bike_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

import '../../key_screens.dart' show loadKeyScreenFonts;

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Bajaj',
  model: 'Pulsar 150',
  odometerKm: 12000,
  createdAt: DateTime(2025, 1, 1),
);

class _Garage extends GarageNotifier {
  _Garage(this.bikes);
  final List<BikeEntity> bikes;
  @override
  Future<List<BikeEntity>> build() async => bikes;
}

class _Logs extends MaintenanceNotifier {
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async => const [];
}

class _Configs extends MaintenanceConfigNotifier {
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async => const [];
}

class _Papers extends PaperworkNotifier {
  @override
  Future<List<PaperworkEntity>> build(String bikeId) async => const [];
}

var _fuelFails = false;

class _FlakyFuel extends FuelLogsNotifier {
  @override
  Future<List<FuelLogEntity>> build(String bikeId) async {
    if (_fuelFails) throw StateError('db closed');
    return [_fill('f1', DateTime(2026, 10, 1), 5, 650)];
  }
}

class _Fuel extends FuelLogsNotifier {
  _Fuel(this.logs);
  final List<FuelLogEntity> logs;
  @override
  Future<List<FuelLogEntity>> build(String bikeId) async => logs;
}

CheckForecast _check(String key, ServiceType type, ReminderStatus status,
        {double? kmLeft}) =>
    CheckForecast(
      key: key,
      serviceType: type,
      status: status,
      kmLimit: 3000,
      baseKmLimit: 3000,
      kmLeft: kmLeft,
    );

final _checks = [
  _check('oil', ServiceType.oilChange, ReminderStatus.dueSoon, kmLeft: 180),
  _check('chain', ServiceType.chain, ReminderStatus.ok, kmLeft: 400),
  _check('brakes', ServiceType.frontDiscPads, ReminderStatus.overdue,
      kmLeft: -50),
  _check('air', ServiceType.airFilter, ReminderStatus.unknown),
];

FuelLogEntity _fill(String id, DateTime at, double litres, double cost) =>
    FuelLogEntity(
      id: id,
      bikeId: 'b1',
      filledAt: at,
      odometerKm: 12000,
      liters: litres,
      totalCost: cost,
      pricePerLiter: cost / litres,
      createdAt: at,
      updatedAt: at,
    );

PlaceEntity _place(String id, PlaceCategory category, double dLat,
        {String? phone}) =>
    PlaceEntity(
      id: id,
      name: 'Place $id',
      category: category,
      latitude: 23.78 + dLat,
      longitude: 90.40,
      geohash: 'wh0r',
      address: 'Dhaka',
      phone: phone,
      createdBy: 'u2',
      createdAt: DateTime(2026),
    );

final _position = Position(
  latitude: 23.78,
  longitude: 90.40,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  final en = AppLocalizationsEn();
  setUpAll(loadKeyScreenFonts);

  late int positionReads;
  Object? positionError;

  List<Override> overrides({
    List<BikeEntity>? bikes,
    List<CheckForecast>? checks,
    List<FuelLogEntity> fuel = const [],
    List<PlaceEntity> places = const [],
    bool fakeFuel = true,
  }) =>
      [
        garageProvider.overrideWith(() => _Garage(bikes ?? [_bike])),
        currentUserProvider.overrideWithValue(null),
        maintenanceForecastProvider
            .overrideWith((ref, id) => checks ?? _checks),
        maintenanceProvider.overrideWith(_Logs.new),
        maintenanceConfigProvider.overrideWith(_Configs.new),
        paperworkProvider.overrideWith(_Papers.new),
        if (fakeFuel) fuelLogsProvider.overrideWith(() => _Fuel(fuel)),
        currentPositionProvider.overrideWith((ref) async {
          positionReads++;
          if (positionError case final e?) throw e;
          return _position;
        }),
        nearbyPlacesProvider.overrideWith((ref, radius) async {
          await ref.watch(currentPositionProvider.future);
          return places;
        }),
      ];

  setUp(() {
    positionReads = 0;
    positionError = null;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScope(WidgetTester tester, Widget scope) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
  }

  Widget app({double textScale = 1, Locale locale = const Locale('en')}) {
    final router = GoRouter(initialLocation: '/home/simple-bike', routes: [
      GoRoute(
          path: '/home/simple-bike',
          builder: (_, __) => const SimpleBikeScreen()),
      GoRoute(
          path: '/home/maintenance/setup',
          builder: (_, s) => Text('SETUP ${s.uri.query}')),
      GoRoute(
          path: '/home/maintenance/fuel/add',
          builder: (_, s) => Text('ADD FUEL ${s.uri.query}')),
      GoRoute(
          path: '/home/profile/add',
          builder: (_, __) => const Text('ADD BIKE')),
    ]);
    return MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    List<BikeEntity>? bikes,
    List<CheckForecast>? checks,
    List<FuelLogEntity> fuel = const [],
    List<PlaceEntity> places = const [],
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) =>
      pumpScope(
        tester,
        ProviderScope(
          overrides: overrides(
              bikes: bikes, checks: checks, fuel: fuel, places: places),
          child: app(textScale: textScale, locale: locale),
        ),
      );

  Finder row(String key) => find.byKey(Key('simpleBikeCheck_$key'));

  testWidgets('checklist: each tracked check with OK or when it is due',
      (tester) async {
    await pump(tester);
    expect(row('air'), findsNothing); // unknown is skipped
    expect(find.descendant(of: row('chain'), matching: find.text('OK')),
        findsOneWidget);
    expect(
        find.descendant(of: row('brakes'), matching: find.text(en.dueOverdue)),
        findsOneWidget);
    // No riding pace to date it, so it falls back to the km left.
    expect(
        find.descendant(
            of: row('oil'),
            matching: find.text(rowRemainingText(_checks[0], en, false))),
        findsOneWidget);
    expect(find.byType(PaperworkCard), findsOneWidget);
  });

  testWidgets('Done opens the quick service sheet for that check',
      (tester) async {
    await pump(tester);
    await tester.tap(find.descendant(
        of: row('oil'), matching: find.text(en.simpleBikeCheckDone)));
    await tester.pumpAndSettle();
    final sheet =
        tester.widget<QuickServiceSheet>(find.byType(QuickServiceSheet));
    expect(sheet.bike.id, 'b1');
    expect(sheet.initialForecast?.key, 'oil');
    expect(sheet.initialServiceType, ServiceType.oilChange);
  });

  testWidgets('no tracked checks: Set up maintenance opens first-time setup',
      (tester) async {
    await pump(tester, checks: [_checks.last]);
    await tester.tap(find.byKey(const Key('simpleBikeSetup')));
    await tester.pumpAndSettle();
    expect(find.text('SETUP bikeId=b1&firstTime=true'), findsOneWidget);
  });

  testWidgets('fuel history: date, taka and litres, newest first',
      (tester) async {
    await pump(tester, fuel: [
      _fill('f1', DateTime(2026, 10, 1), 10, 1250),
      _fill('f2', DateTime(2026, 11, 1), 4.5, 585),
    ]);
    final newest = find.byKey(const Key('simpleBikeFuel_f2'));
    expect(
        tester.getTopLeft(newest).dy,
        lessThan(
            tester.getTopLeft(find.byKey(const Key('simpleBikeFuel_f1'))).dy));
    expect(find.descendant(of: newest, matching: find.text('1 Nov 2026')),
        findsOneWidget);
    expect(
        find.descendant(
            of: newest,
            matching: find.text('৳585 · ${en.simpleBikeFuelLitres('4.5')}')),
        findsOneWidget);
    // Same thousands grouping as the Home tile.
    expect(
        find.descendant(
            of: find.byKey(const Key('simpleBikeFuel_f1')),
            matching: find.text('৳1,250 · ${en.simpleBikeFuelLitres('10.0')}')),
        findsOneWidget);
  });

  testWidgets('fuel history that fails to load is not shown as none',
      (tester) async {
    _fuelFails = true;
    addTearDown(() => _fuelFails = false);
    await pumpScope(
      tester,
      ProviderScope(
        overrides: [
          ...overrides(fakeFuel: false),
          fuelLogsProvider.overrideWith(_FlakyFuel.new),
        ],
        child: app(),
      ),
    );
    expect(find.text(en.simpleBikeFuelEmpty), findsNothing);
    expect(find.byKey(const Key('simpleBikeFuelFailed')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('simpleBikeFuelRetry'))).height,
        greaterThanOrEqualTo(48));

    _fuelFails = false;
    await tester.tap(find.byKey(const Key('simpleBikeFuelRetry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simpleBikeFuelFailed')), findsNothing);
    expect(find.byKey(const Key('simpleBikeFuel_f1')), findsOneWidget);
  });

  testWidgets('no fuel yet: Add fuel opens the fill-up form', (tester) async {
    await pump(tester);
    expect(find.text(en.simpleBikeFuelEmpty), findsOneWidget);
    await tester.tap(find.byKey(const Key('simpleBikeAddFuel')));
    await tester.pumpAndSettle();
    expect(find.text('ADD FUEL bikeId=b1'), findsOneWidget);
  });

  testWidgets('no bike: Add bike', (tester) async {
    await pump(tester, bikes: []);
    await tester.tap(find.widgetWithText(FilledButton, en.simpleBikeAddBike));
    await tester.pumpAndSettle();
    expect(find.text('ADD BIKE'), findsOneWidget);
  });

  testWidgets('Find nearby is hidden with the Places module off',
      (tester) async {
    SharedPreferences.setMockInitialValues({'module_places': false});
    await pump(tester);
    expect(find.text(en.simpleBikeNearbyTitle.toUpperCase()), findsNothing);
    expect(find.byKey(const Key('simpleBikeFindNearby')), findsNothing);
  });

  testWidgets(
      'Find nearby: nothing loads until tapped, then nearest first per kind',
      (tester) async {
    await pump(tester, places: [
      _place('fuelFar', PlaceCategory.fuel, 0.05),
      _place('fuelNear', PlaceCategory.fuel, 0.01, phone: '01711-000000'),
      _place('garage', PlaceCategory.garage, 0.02, phone: '01811000000'),
      _place('parts', PlaceCategory.parts, 0.001),
    ]);
    expect(positionReads, 0);

    await tester.tap(find.byKey(const Key('simpleBikeFindNearby')));
    await tester.pumpAndSettle();
    expect(positionReads, 1);

    Finder card(String id) => find.byKey(Key('simpleBikePlace_$id'));
    expect(tester.getTopLeft(card('fuelNear')).dy,
        lessThan(tester.getTopLeft(card('fuelFar')).dy));
    expect(tester.getTopLeft(find.text(en.simpleBikeNearbyGarage)).dy,
        greaterThan(tester.getTopLeft(card('fuelFar')).dy));
    expect(card('garage'), findsOneWidget);
    expect(card('parts'), findsNothing);
    // Call only where there is a number; Directions everywhere.
    expect(find.descendant(of: card('fuelFar'), matching: find.text(en.call)),
        findsNothing);
    expect(find.descendant(of: card('fuelNear'), matching: find.text(en.call)),
        findsOneWidget);
    expect(
        find.descendant(
            of: card('fuelFar'), matching: find.text(en.directions)),
        findsOneWidget);
    expect(
        find.descendant(
            of: card('fuelNear'), matching: find.text('1.1 km away')),
        findsOneWidget);
  });

  testWidgets('Find nearby: a location error offers retry', (tester) async {
    positionError =
        const PlaceLocationException(PlaceLocationProblem.serviceDisabled);
    await pump(tester, places: [_place('g', PlaceCategory.garage, 0.01)]);
    await tester.tap(find.byKey(const Key('simpleBikeFindNearby')));
    await tester.pumpAndSettle();
    expect(find.text(en.errLocationOff), findsOneWidget);

    positionError = null;
    await tester.tap(find.byKey(const Key('simpleBikeNearbyRetry')));
    await tester.pumpAndSettle();
    expect(find.text(en.errLocationOff), findsNothing);
    expect(find.byKey(const Key('simpleBikePlace_g')), findsOneWidget);
  });

  testWidgets('a fill saved through fuelLogsProvider shows in fuel history',
      (tester) async {
    // The full app's Add fuel form saves through this notifier, into SQLite.
    final db = (await tester.runAsync(() async {
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false));
      await DatabaseHelper.instance.createSchemaForTesting(db);
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u1',
        'brand': 'Bajaj',
        'model': 'Pulsar 150',
        'created_at': '2025-01-01T00:00:00.000',
      });
      return db;
    }))!;
    DatabaseHelper.overrideDatabaseForTesting(db);
    addTearDown(() => DatabaseHelper.overrideDatabaseForTesting(null));

    final container = ProviderContainer(overrides: overrides(fakeFuel: false));
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(fuelLogsProvider('b1').future);
      await container.read(fuelLogsProvider('b1').notifier).save(FuelLogDraft(
            filledAt: DateTime(2026, 11, 20),
            odometerKm: 12100,
            liters: 5,
            totalCost: 650,
            pricePerLiter: 130,
          ));
      await container.read(fuelLogsProvider('b1').future);
    });

    await pumpScope(
        tester, UncontrolledProviderScope(container: container, child: app()));
    expect(find.text('20 Nov 2026'), findsOneWidget);
    expect(
        find.text('৳650 · ${en.simpleBikeFuelLitres('5.0')}'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('no overflow at 2x text (${locale.languageCode})',
        (tester) async {
      await pump(tester,
          fuel: [_fill('f1', DateTime(2026, 10, 1), 5, 650)],
          places: [
            _place('f', PlaceCategory.fuel, 0.01, phone: '01711000000'),
            _place('g', PlaceCategory.garage, 0.02, phone: '01811000000'),
          ],
          textScale: 2,
          locale: locale);
      await tester.tap(find.byKey(const Key('simpleBikeFindNearby')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await pump(tester, checks: const [], textScale: 2, locale: locale);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, bikes: [], textScale: 2, locale: locale);
    });
  }
}
