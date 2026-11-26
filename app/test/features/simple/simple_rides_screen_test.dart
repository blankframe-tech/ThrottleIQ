import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_rides_screen.dart';
import 'package:throttleiq/features/simple/presentation/widgets/simple_rides_week_bars.dart';
import 'package:throttleiq/features/stats/presentation/providers/ride_polyline_provider.dart';
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

RideEntity _ride(String id, DateTime start,
        {RideStatus status = RideStatus.completed}) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: 'b1',
      startTime: start,
      status: status,
      distanceM: 12480,
      durationSeconds: 1661,
      movingSeconds: 1500,
    );

class _Garage extends GarageNotifier {
  _Garage(this.bikes);
  final List<BikeEntity> bikes;
  @override
  Future<List<BikeEntity>> build() async => bikes;
}

const _fuelOnly = RideCostBreakdown(distanceKm: 12.48, lines: [
  RideCostLine(
      serviceType: ServiceType.fuel,
      costPerKm: 5,
      cost: 62.4,
      source: CostSource.fuel),
]);

void main() {
  final en = AppLocalizationsEn();
  final now = DateTime.now();
  setUpAll(loadKeyScreenFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    List<BikeEntity>? bikes,
    List<RideEntity> rides = const [],
    RideCostBreakdown? cost = _fuelOnly,
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/home/simple-rides', routes: [
      GoRoute(
        path: '/home/simple-rides',
        builder: (_, __) => const SimpleRidesScreen(),
        routes: [
          GoRoute(
              path: ':rideId',
              builder: (_, s) => Text('DETAIL ${s.pathParameters['rideId']}')),
        ],
      ),
      GoRoute(
          path: '/home/profile/add',
          builder: (_, __) => const Text('ADD BIKE')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        garageProvider.overrideWith(() => _Garage(bikes ?? [_bike])),
        rideHistoryProvider.overrideWith((ref, id) async => rides),
        ridePolylineProvider.overrideWith((ref, id) async => const []),
        rideCostProvider.overrideWith((ref, key) => cost),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final older = _ride('r1', now.subtract(const Duration(days: 2)));
  final newer = _ride('r2', now.subtract(const Duration(hours: 1)));
  final live = _ride('r3', now, status: RideStatus.active);
  final paused = _ride('r4', now, status: RideStatus.paused);

  testWidgets('finished rides newest first, with km, time and fuel cost',
      (tester) async {
    await pump(tester, rides: [older, live, newer, paused]);

    expect(find.byType(SimpleRidesWeekBars), findsOneWidget);
    expect(find.byKey(const Key('simpleRideCard_r3')), findsNothing);
    expect(find.byKey(const Key('simpleRideCard_r4')), findsNothing);
    final top = tester.getTopLeft(find.byKey(const Key('simpleRideCard_r2')));
    final below = tester.getTopLeft(find.byKey(const Key('simpleRideCard_r1')));
    expect(top.dy, lessThan(below.dy));
    expect(find.text('12.5 km'), findsNWidgets(2));
    expect(find.text(en.simpleRidesDurationM(28)), findsNWidgets(2));
    expect(find.text(en.simpleRidesFuelCost('62')), findsNWidgets(2));
  });

  testWidgets('no running-cost data: the fuel cost is left out',
      (tester) async {
    await pump(tester, rides: [newer], cost: null);
    expect(find.text('12.5 km'), findsOneWidget);
    expect(find.textContaining('৳'), findsNothing);

    // Costs for other items but no fuel price: still no fuel figure.
    await tester.pumpWidget(const SizedBox());
    await pump(tester,
        rides: [newer],
        cost: const RideCostBreakdown(distanceKm: 12.48, lines: [
          RideCostLine(
              serviceType: ServiceType.oilChange,
              costPerKm: 1,
              cost: 12,
              source: CostSource.typical),
        ]));
    expect(find.textContaining('৳'), findsNothing);
  });

  testWidgets('tapping a ride opens /home/simple-rides/<id>', (tester) async {
    await pump(tester, rides: [newer]);
    await tester.tap(find.byKey(const Key('simpleRideCard_r2')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL r2'), findsOneWidget);
  });

  testWidgets('no rides: START RIDE', (tester) async {
    await pump(tester, rides: [live]);
    expect(find.text(en.simpleRidesEmptyTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, en.simpleRidesStartRide),
        findsOneWidget);
    expect(find.byType(SimpleRidesWeekBars), findsNothing);
  });

  testWidgets('no bike: Add bike opens the add-bike form', (tester) async {
    await pump(tester, bikes: []);
    expect(find.text(en.simpleRidesNoBikeTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.simpleRidesAddBike));
    await tester.pumpAndSettle();
    expect(find.text('ADD BIKE'), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('no overflow at 2x text (${locale.languageCode})',
        (tester) async {
      await pump(tester, rides: [older, newer], textScale: 2, locale: locale);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, rides: const [], textScale: 2, locale: locale);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, bikes: [], textScale: 2, locale: locale);
    });
  }
}
