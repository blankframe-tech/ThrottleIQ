import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_profile.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/fuel_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/service_type_l10n.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/quick_service_sheet.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_provider.dart';
import 'package:throttleiq/features/profile/domain/entities/emergency_contact_entity.dart';
import 'package:throttleiq/features/profile/presentation/providers/emergency_contacts_provider.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_home_screen.dart';
import 'package:throttleiq/features/simple/presentation/widgets/simple_home_help_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

import '../../key_screens.dart' show loadKeyScreenFonts;

final _en = AppLocalizationsEn();
final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month, 1, 0, 30);
final _lastMonth = DateTime(_now.year, _now.month, 0, 12);

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Bajaj',
  model: 'Pulsar 150',
  isActive: true,
  createdAt: DateTime(2025),
);

RideEntity _ride(String id, DateTime start, double km,
        [RideStatus status = RideStatus.completed]) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: 'b1',
      startTime: start,
      distanceM: km * 1000,
      status: status,
    );

FuelLogEntity _fill(String id, DateTime at, double odo, double taka) =>
    FuelLogEntity(
      id: id,
      bikeId: 'b1',
      filledAt: at,
      odometerKm: odo,
      liters: taka / 125,
      totalCost: taka,
      pricePerLiter: 125,
      createdAt: at,
      updatedAt: at,
    );

CheckForecast _forecast(ServiceType t, ReminderStatus s, {double? kmLeft}) =>
    CheckForecast(
      key: t.name,
      serviceType: t,
      status: s,
      kmLimit: 3000,
      baseKmLimit: 3000,
      kmLeft: kmLeft,
    );

PlaceEntity _place(String id, PlaceCategory category) => PlaceEntity(
      id: id,
      name: 'Place $id',
      category: category,
      latitude: 23.79,
      longitude: 90.40,
      geohash: 'wh0r',
      address: 'Dhaka',
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

/// Where Settings' add-contact dialog writes, per pump.
late FakeFirebaseFirestore _firestore;

PaperworkEntity _paper(PaperworkKind k, int days) => PaperworkEntity(
    bikeId: 'b1', kind: k, expiresOn: _now.add(Duration(days: days)));

class _Garage extends GarageNotifier {
  _Garage(this.bikes);
  final List<BikeEntity> bikes;
  @override
  Future<List<BikeEntity>> build() async => bikes;
}

/// Saves into its own state: the same provider Home reads.
class _Fuel extends FuelLogsNotifier {
  _Fuel(this.initial);
  final List<FuelLogEntity> initial;
  @override
  Future<List<FuelLogEntity>> build(String bikeId) async => initial;
  @override
  Future<String> save(FuelLogDraft d, {String? id}) async {
    final e = FuelLogEntity(
      id: 'new',
      bikeId: arg,
      filledAt: d.filledAt,
      odometerKm: d.odometerKm,
      liters: d.liters,
      totalCost: d.totalCost,
      pricePerLiter: d.pricePerLiter,
      createdAt: d.filledAt,
      updatedAt: d.filledAt,
    );
    state = AsyncData([e, ...state.requireValue]);
    return e.id;
  }
}

class _Papers extends PaperworkNotifier {
  _Papers(this.papers);
  final List<PaperworkEntity> papers;
  @override
  Future<List<PaperworkEntity>> build(String bikeId) async => papers;
}

class _Modules extends StateNotifier<AppModules> implements AppModulesNotifier {
  _Modules(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recorder extends StateNotifier<RideRecordingState>
    implements RideRecordingNotifier {
  _Recorder(super.state);
  int starts = 0;
  @override
  Future<void> startRide({
    bool userInitiated = true,
    String? bikeId,
    BikeAttributionConfidence bikeConfidence = BikeAttributionConfidence.high,
    String? routeId,
    String? routeName,
  }) async {
    starts++;
    state = const RideRecordingState(status: RecordingStatus.active);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<BikeEntity>? bikes,
  List<RideEntity> rides = const [],
  List<FuelLogEntity> fills = const [],
  List<CheckForecast> forecasts = const [],
  List<PaperworkEntity> papers = const [],
  List<EmergencyContactEntity> contacts = const [],
  bool contactsFail = false,
  bool ridesFail = false,
  AppModules modules = const AppModules(simple: true),
  RideRecordingState recording = const RideRecordingState(),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  _firestore = FakeFirebaseFirestore();
  final container = ProviderContainer(overrides: [
    garageProvider.overrideWith(() => _Garage(bikes ?? [_bike])),
    appModulesProvider.overrideWith((ref) => _Modules(modules)),
    rideRecordingProvider.overrideWith((ref) => _Recorder(recording)),
    rideHistoryProvider.overrideWith(
        (ref, id) async => ridesFail ? throw StateError('db') : rides),
    fuelLogsProvider.overrideWith(() => _Fuel(fills)),
    maintenanceForecastProvider.overrideWith((ref, id) => forecasts),
    paperworkProvider.overrideWith(() => _Papers(papers)),
    myEmergencyContactsProvider.overrideWith((ref) => contactsFail
        ? Stream.error(StateError('permission-denied'))
        : Stream.value(contacts)),
    emergencyContactsNotifierProvider
        .overrideWith((ref) => EmergencyContactsNotifier('u1', _firestore)),
    currentPositionProvider.overrideWith((ref) async => _position),
    nearbyPlacesProvider.overrideWith((ref, radius) async => [
          _place('fuel1', PlaceCategory.fuel),
          _place('mech1', PlaceCategory.garage),
        ]),
  ]);
  addTearDown(container.dispose);
  Widget at(GoRouterState s) => Scaffold(body: Text('at ${s.uri}'));
  final router = GoRouter(initialLocation: '/home/simple', routes: [
    GoRoute(path: '/home/simple', builder: (_, __) => const SimpleHomeScreen()),
    for (final p in [
      '/home/profile/add',
      '/home/maintenance/fuel/add',
      '/home/simple-bike',
      '/settings',
      '/ride/active',
    ])
      GoRoute(path: p, builder: (_, s) => at(s)),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: AppTheme.build(const AppAppearance(brightness: Brightness.light)),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations: true, textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  setUpAll(loadKeyScreenFonts);

  group('empty states, one fixing button each', () {
    testWidgets('no bike → Add bike', (tester) async {
      await _pump(tester, bikes: []);
      expect(find.text(_en.simpleHomeNoBike), findsOneWidget);
      expect(_key('simple_home_start_ride'), findsNothing);
      await tester.tap(_key('simple_home_add_bike'));
      await tester.pumpAndSettle();
      expect(find.text('at /home/profile/add'), findsOneWidget);
    });

    testWidgets('no rides → the one START RIDE button', (tester) async {
      await _pump(tester);
      expect(_key('simple_home_no_rides'), findsOneWidget);
      expect(find.text(_en.simpleHomeStartRide), findsOneWidget);
    });

    testWidgets('no fuel → Add fuel', (tester) async {
      await _pump(tester);
      expect(_key('simple_home_no_fuel'), findsOneWidget);
      expect(_key('simple_home_mileage'), findsNothing);
      expect(find.text(_en.simpleHomeAddFuel), findsOneWidget);
    });
  });

  testWidgets('tiles sum only this calendar month', (tester) async {
    await _pump(tester, rides: [
      _ride('a', _thisMonth, 10),
      _ride('b', _thisMonth, 2.4, RideStatus.crash),
      _ride('c', _thisMonth, 50, RideStatus.active),
      _ride('d', _lastMonth, 100),
    ], fills: [
      _fill('x', _thisMonth, 1200, 500),
      _fill('y', _thisMonth, 1100, 300),
      _fill('z', _lastMonth, 1000, 1000),
    ]);
    expect(
        find.descendant(of: _key('simple_home_km'), matching: find.text('12')),
        findsOneWidget);
    expect(
        find.descendant(
            of: _key('simple_home_taka'), matching: find.text('৳800')),
        findsOneWidget);
    expect(_key('simple_home_no_rides'), findsNothing);
    expect(_key('simple_home_no_fuel'), findsNothing);
  });

  testWidgets('one fill: mileage says not enough data yet', (tester) async {
    await _pump(tester, fills: [_fill('1', _lastMonth, 0, 500)]);
    expect(find.text(_en.simpleHomeMileageNotEnough), findsOneWidget);
  });

  testWidgets('two full fills: the km/L, as in the full app, not judged yet',
      (tester) async {
    await _pump(tester, fills: [
      _fill('1', _lastMonth, 0, 500),
      _fill('2', _lastMonth.add(const Duration(hours: 1)), 100, 250),
    ]);
    // 100 km on 2 L.
    expect(find.text(_en.simpleHomeMileageFirst('50')), findsOneWidget);
    expect(find.text(_en.simpleHomeMileageNotEnough), findsNothing);
  });

  testWidgets('a failed ride load shows a dash, not 0 km', (tester) async {
    await _pump(tester, ridesFail: true);
    expect(
        find.descendant(of: _key('simple_home_km'), matching: find.text('—')),
        findsOneWidget);
    expect(_key('simple_home_no_rides'), findsNothing);
  });

  testWidgets('thousands are grouped in both tiles', (tester) async {
    await _pump(tester,
        rides: [_ride('a', _thisMonth, 1234)],
        fills: [_fill('x', _thisMonth, 1200, 1250)]);
    expect(
        find.descendant(
            of: _key('simple_home_km'), matching: find.text('1,234')),
        findsOneWidget);
    expect(
        find.descendant(
            of: _key('simple_home_taka'), matching: find.text('৳1,250')),
        findsOneWidget);
  });

  testWidgets('mileage line shows the verdict', (tester) async {
    await _pump(tester, fills: [
      _fill('1', _lastMonth, 0, 500),
      _fill('2', _lastMonth.add(const Duration(hours: 1)), 100, 250),
      _fill('3', _lastMonth.add(const Duration(hours: 2)), 200, 250),
    ]);
    // 100 km on 2 L, twice: 50 km/L, same as usual.
    expect(find.text(_en.simpleHomeMileageGood('50')), findsOneWidget);
  });

  group('one alert, most urgent first', () {
    final overdue = _forecast(ServiceType.oilChange, ReminderStatus.overdue);
    final soon = _forecast(ServiceType.chain, ReminderStatus.dueSoon);
    final expired = _paper(PaperworkKind.insurance, -3);
    final expiring = _paper(PaperworkKind.taxToken, 12);
    final oil = ServiceType.oilChange.localizedLabel(_en);
    final chain = ServiceType.chain.localizedLabel(_en);

    testWidgets('overdue service beats papers and due-soon', (tester) async {
      await _pump(tester,
          forecasts: [soon, overdue], papers: [expiring, expired]);
      expect(_key('simple_home_alert'), findsOneWidget);
      expect(find.textContaining(oil), findsOneWidget);
      expect(find.textContaining(_en.paperworkInsurance), findsNothing);
    });

    testWidgets('expired paper, then expiring, then due-soon', (tester) async {
      await _pump(tester, forecasts: [soon], papers: [expiring, expired]);
      expect(find.textContaining(_en.paperworkInsurance), findsOneWidget);
      expect(_key('simple_home_renew'), findsOneWidget);
    });

    testWidgets('expiring paper beats due-soon', (tester) async {
      await _pump(tester,
          forecasts: [soon],
          papers: [_paper(PaperworkKind.insurance, 90), expiring]);
      expect(find.textContaining(_en.paperworkTaxToken), findsOneWidget);
      expect(find.textContaining(chain), findsNothing);
    });

    testWidgets('due-soon, else nothing; low-stakes and unknown skipped',
        (tester) async {
      await _pump(tester, forecasts: [
        _forecast(ServiceType.fuel, ReminderStatus.overdue),
        _forecast(ServiceType.frontDiscPads, ReminderStatus.unknown),
        soon,
      ]);
      expect(find.textContaining(chain), findsOneWidget);
      expect(_key('simple_home_alert'), findsOneWidget);
    });

    testWidgets('an undatable km-only check still says how far',
        (tester) async {
      await _pump(tester, forecasts: [
        _forecast(ServiceType.frontDiscPads, ReminderStatus.dueSoon,
            kmLeft: 180)
      ]);
      expect(find.textContaining(_en.rowLeftKm('180 km')), findsOneWidget);
    });

    testWidgets('no alert when all is fine', (tester) async {
      await _pump(tester, papers: [_paper(PaperworkKind.insurance, 90)]);
      expect(_key('simple_home_alert'), findsNothing);
    });

    testWidgets('Find mechanic lists nearby mechanics at once', (tester) async {
      await _pump(tester, forecasts: [overdue]);
      await tester.tap(_key('simple_home_find_mechanic'));
      await tester.pumpAndSettle();
      expect(_key('simpleBikePlace_mech1'), findsOneWidget);
      expect(_key('simpleBikePlace_fuel1'), findsNothing);
      expect(_key('simpleBikeFindNearby'), findsNothing);
    });

    testWidgets('Find mechanic is hidden with Places off', (tester) async {
      await _pump(tester,
          forecasts: [overdue],
          modules: const AppModules(simple: true, places: false));
      expect(_key('simple_home_find_mechanic'), findsNothing);
      expect(_key('simple_home_done'), findsOneWidget);
    });

    testWidgets('Done opens QuickServiceSheet', (tester) async {
      await _pump(tester, forecasts: [overdue]);
      await tester.tap(_key('simple_home_done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final sheet =
          tester.widget<QuickServiceSheet>(find.byType(QuickServiceSheet));
      expect(sheet.bike.id, 'b1');
      expect(sheet.initialForecast, same(overdue));
      expect(sheet.initialServiceType, ServiceType.oilChange);
      expect(sheet.initialTitle, oil);
    });
  });

  group('Help', () {
    final mum = EmergencyContactEntity(
        id: 'c1', name: 'Mum', phone: '+880 1711-000000', createdAt: _now);

    testWidgets('with contacts: Call and Send my location', (tester) async {
      await _pump(tester, contacts: [mum]);
      await tester.tap(_key('simple_home_help'));
      await tester.pumpAndSettle();
      expect(find.text('Mum'), findsOneWidget);
      expect(_key('simple_home_call_c1'), findsOneWidget);
      expect(_key('simple_home_send_location_c1'), findsOneWidget);
      expect(find.textContaining(RegExp('automatic', caseSensitive: false)),
          findsNothing);
    });

    testWidgets(
        "without contacts: Settings' add dialog, saving to the same place",
        (tester) async {
      await _pump(tester);
      await tester.tap(_key('simple_home_help'));
      await tester.pumpAndSettle();
      expect(_key('simple_home_call_c1'), findsNothing);
      expect(find.textContaining(RegExp('automatic', caseSensitive: false)),
          findsNothing);
      await tester.tap(_key('simple_home_add_contact'));
      await tester.pumpAndSettle();
      expect(find.text(_en.addEmergencyContactTitle), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Mum');
      await tester.enterText(fields.at(1), '01711000000');
      await tester.tap(find.widgetWithText(ElevatedButton, _en.addAction));
      await tester.pumpAndSettle();
      final saved = await _firestore
          .collection('users')
          .doc('u1')
          .collection('emergencyContacts')
          .get();
      expect(saved.docs.single.data()['name'], 'Mum');
    });

    testWidgets("contacts that fail to load aren't shown as none",
        (tester) async {
      await _pump(tester, contactsFail: true);
      await tester.tap(_key('simple_home_help'));
      await tester.pumpAndSettle();
      expect(_key('simple_home_contacts_failed'), findsOneWidget);
      expect(_key('simple_home_contacts_retry'), findsOneWidget);
      expect(find.text(_en.simpleHomeNoContacts), findsNothing);
      expect(_key('simple_home_add_contact'), findsNothing);
    });

    test('the location SMS: number, encoded body with a Maps link', () {
      final uri = locationSmsUri(
          '+880 1711-000000', 23.81, 90.41, _en.simpleHomeLocationSms);
      expect(uri.scheme, 'sms');
      expect(uri.path, '+8801711000000');
      expect(uri.query, contains('%20'));
      expect(uri.query, isNot(contains('+')));
      expect(Uri.decodeComponent(uri.query),
          "body=I need help. I'm here: https://maps.google.com/?q=23.81,90.41");
    });
  });

  group('START RIDE', () {
    testWidgets('hidden when ride tracking is off', (tester) async {
      await _pump(tester,
          modules: const AppModules(simple: true, rideTracking: false));
      expect(_key('simple_home_start_ride'), findsNothing);
      expect(_key('simple_home_no_rides'), findsNothing);
      // km comes only from recorded rides, so no false "0 km".
      expect(_key('simple_home_km'), findsNothing);
      expect(_key('simple_home_taka'), findsOneWidget);
    });

    testWidgets('starts a ride through the recorder, then opens it',
        (tester) async {
      final c = await _pump(tester);
      await tester.tap(_key('simple_home_start_ride'));
      await tester.pumpAndSettle();
      expect((c.read(rideRecordingProvider.notifier) as _Recorder).starts, 1);
      expect(find.text('at /ride/active'), findsOneWidget);
    });

    testWidgets('a running ride: the button opens it', (tester) async {
      final c = await _pump(tester,
          recording: const RideRecordingState(status: RecordingStatus.paused));
      expect(find.text(_en.simpleHomeOpenRide), findsOneWidget);
      await tester.tap(_key('simple_home_start_ride'));
      await tester.pumpAndSettle();
      expect((c.read(rideRecordingProvider.notifier) as _Recorder).starts, 0);
      expect(find.text('at /ride/active'), findsOneWidget);
    });
  });

  testWidgets(
      'same provider: a fill saved through fuelLogsProvider shows up; '
      'Add fuel opens the shared form', (tester) async {
    final c = await _pump(tester);
    expect(
        find.descendant(
            of: _key('simple_home_taka'), matching: find.text('৳0.0')),
        findsOneWidget);
    await c.read(fuelLogsProvider('b1').notifier).save(FuelLogDraft(
          filledAt: _now,
          odometerKm: 1000,
          liters: 4,
          totalCost: 520,
          pricePerLiter: 130,
        ));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: _key('simple_home_taka'), matching: find.text('৳520')),
        findsOneWidget);
    await tester.tap(_key('simple_home_add_fuel'));
    await tester.pumpAndSettle();
    expect(
        find.text('at /home/maintenance/fuel/add?bikeId=b1'), findsOneWidget);
  });

  testWidgets('touch targets are at least 48dp', (tester) async {
    await _pump(tester,
        forecasts: [_forecast(ServiceType.oilChange, ReminderStatus.overdue)]);
    for (final k in [
      'simple_home_start_ride',
      'simple_home_add_fuel',
      'simple_home_help',
      'simple_home_find_mechanic',
      'simple_home_done',
      'simple_settings_button',
    ]) {
      expect(tester.getSize(_key(k)).height, greaterThanOrEqualTo(48),
          reason: k);
    }
  });

  // Overflow fails the test on its own (a FlutterError).
  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('no overflow at text scale 2.0 (${locale.languageCode})',
        (tester) async {
      await _pump(tester, locale: locale, textScale: 2, rides: [
        _ride('a', _thisMonth, 1234)
      ], fills: [
        _fill('1', _lastMonth, 0, 500),
        _fill('2', _lastMonth.add(const Duration(hours: 1)), 100, 250),
        _fill('3', _lastMonth.add(const Duration(hours: 2)), 200, 400),
      ], forecasts: [
        _forecast(ServiceType.oilChange, ReminderStatus.overdue)
      ]);
      expect(_key('simple_home_alert'), findsOneWidget);
      // Scrolling lays out every row on the way down.
      await tester.scrollUntilVisible(_key('simple_home_help'), 200);
      await tester.tap(_key('simple_home_help'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
