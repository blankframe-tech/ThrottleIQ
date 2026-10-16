import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/running_costs_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _Running extends BikeRunningCostNotifier {
  @override
  Future<BikeRunningCostEntity> build(String bikeId) async =>
      BikeRunningCostEntity(bikeId: bikeId);
}

class _Logs extends MaintenanceNotifier {
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async => const [];
}

class _Configs extends MaintenanceConfigNotifier {
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async => const [];
}

Widget _harness(RideCostBreakdown breakdown) => ProviderScope(
      overrides: [
        rideCostProvider.overrideWith((ref, key) => breakdown),
        bikeRunningCostProvider.overrideWith(_Running.new),
        maintenanceProvider.overrideWith(_Logs.new),
        maintenanceConfigProvider.overrideWith(_Configs.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: Scaffold(body: RunningCostsSheet(bikeId: 'b1')),
      ),
    );

// ৳5/km: fuel at 125 ৳/l and 25 km/l.
const _fiveTakaPerKm = RideCostBreakdown(distanceKm: 1, lines: [
  RideCostLine(
      serviceType: ServiceType.fuel,
      costPerKm: 5,
      cost: 5,
      source: CostSource.fuel),
]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pickup + trip + home and a fare give cost, unpaid share, profit',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(_fiveTakaPerKm));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tripQuotePickup')), '3');
    await tester.enterText(find.byKey(const Key('tripQuoteTrip')), '8');
    await tester.enterText(find.byKey(const Key('tripQuoteHome')), '9');
    await tester.enterText(find.byKey(const Key('tripQuoteFare')), '80');
    await tester.pump();

    expect(find.text('Costs you ৳100 for 20.0 km'), findsOneWidget);
    expect(find.text('60% of that distance is unpaid'), findsOneWidget);
    expect(find.text('You lose ৳20 on this ride'), findsOneWidget);
  });

  testWidgets('no result until a paid trip is entered', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(_fiveTakaPerKm));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tripQuotePickup')), '3');
    await tester.pump();
    expect(find.byKey(const Key('tripQuoteCost')), findsNothing);
  });

  testWidgets('hidden when the bike has no running-cost data', (tester) async {
    await tester.pumpWidget(
        _harness(const RideCostBreakdown(distanceKm: 1, lines: [])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tripQuoteTrip')), findsNothing);
  });
}
