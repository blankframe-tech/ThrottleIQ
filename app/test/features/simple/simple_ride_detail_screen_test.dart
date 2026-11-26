import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_ride_detail_screen.dart';
import 'package:throttleiq/features/stats/presentation/providers/ride_polyline_provider.dart';
import 'package:throttleiq/features/stats/presentation/widgets/ride_route_thumbnail.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

import '../../key_screens.dart' show loadKeyScreenFonts;

RideEntity _ride({double? maxMs, double? avgMs, int? seconds}) => RideEntity(
      id: 'r1',
      userId: 'u1',
      bikeId: 'b1',
      startTime: DateTime(2026, 11, 20, 8),
      status: RideStatus.completed,
      distanceM: 12480,
      maxSpeedMs: maxMs,
      avgSpeedMs: avgMs,
      durationSeconds: seconds,
    );

void main() {
  final en = AppLocalizationsEn();
  setUpAll(loadKeyScreenFonts);

  Future<void> pump(WidgetTester tester, RideEntity? ride,
      {Future<RideEntity?> Function()? load,
      RideCostBreakdown? cost,
      double textScale = 1,
      Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rideDetailProvider
            .overrideWith((ref, id) => load?.call() ?? Future.value(ride)),
        ridePolylineProvider.overrideWith((ref, id) async => const []),
        rideCostProvider.overrideWith((ref, key) => cost),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SimpleRideDetailScreen(rideId: 'r1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the route and four numbers, each with its unit', (tester) async {
    await pump(tester, _ride(maxMs: 24.2, avgMs: 7.5, seconds: 3900));
    // No points here, so it draws nothing (zero height counts as offstage).
    expect(
        find.byType(RideRouteThumbnail, skipOffstage: false), findsOneWidget);
    expect(find.text('12.5 km'), findsOneWidget);
    expect(find.text(en.simpleRidesDurationHm(1, 5)), findsOneWidget);
    expect(find.text('87 km/h'), findsOneWidget); // 24.2 m/s
    expect(find.text('27 km/h'), findsOneWidget); // 7.5 m/s
    for (final label in [
      en.simpleRidesDistance,
      en.simpleRidesTime,
      en.simpleRidesTopSpeed,
      en.simpleRidesAvgSpeed,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the fuel cost the ride row shows, only when it is known',
      (tester) async {
    await pump(tester, _ride(),
        cost: const RideCostBreakdown(distanceKm: 12.48, lines: [
          RideCostLine(
              serviceType: ServiceType.fuel,
              costPerKm: 5,
              cost: 62.4,
              source: CostSource.fuel),
        ]));
    expect(
        find.descendant(
            of: find.byKey(const Key('simpleRideDetailFuel')),
            matching: find.text('৳62')),
        findsOneWidget);
    expect(find.text(en.simpleRidesFuel), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pump(tester, _ride());
    expect(find.byKey(const Key('simpleRideDetailFuel')), findsNothing);
  });

  testWidgets('missing speed or time shows a dash, not a made-up number',
      (tester) async {
    await pump(tester, _ride());
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('12.5 km'), findsOneWidget);
    expect(find.textContaining('km/h'), findsNothing);
  });

  testWidgets('a ride that is gone says so', (tester) async {
    await pump(tester, null);
    expect(find.text(en.simpleRidesNotFound), findsOneWidget);
  });

  testWidgets('a ride that fails to load offers a 48dp Retry that reloads',
      (tester) async {
    var calls = 0;
    await pump(tester, null,
        load: () async =>
            calls++ == 0 ? throw Exception('db locked') : _ride());
    final retry = find.byKey(const Key('simpleRideDetailRetry'));
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('12.5 km'), findsOneWidget);
    expect(retry, findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('no overflow at 2x text (${locale.languageCode})',
        (tester) async {
      await pump(tester, _ride(maxMs: 24.2, avgMs: 7.5, seconds: 3900),
          textScale: 2, locale: locale);
    });
  }
}
