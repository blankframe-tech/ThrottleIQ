import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/ride_cost_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

Widget _harness(RideCostBreakdown? breakdown, {double distanceKm = 20}) {
  return ProviderScope(
    overrides: [
      rideCostProvider.overrideWith((ref, key) => breakdown),
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
        body: RideCostCard(bikeId: 'b1', distanceKm: distanceKm),
      ),
    ),
  );
}

void main() {
  testWidgets('shows total and per-item breakdown', (tester) async {
    final b = RideCostCalculator.compute(
      distanceKm: 20,
      runningCost: const BikeRunningCostEntity(
          bikeId: 'b1', fuelPricePerLitre: 125, kmPerLitre: 50),
      configs: const [
        MaintenanceConfigEntity(
            bikeId: 'b1',
            serviceType: ServiceType.oilChange,
            intervalKm: 1500,
            typicalCost: 900),
      ],
      logs: const [],
    );
    await tester.pumpWidget(_harness(b));
    await tester.pumpAndSettle();

    expect(find.text('RIDE COST'), findsOneWidget);
    expect(find.text('৳62'), findsOneWidget); // 50 fuel + 12 oil
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('৳50'), findsOneWidget);
    expect(find.text('৳12'), findsOneWidget);
  });

  testWidgets('no cost data → setup hint', (tester) async {
    await tester.pumpWidget(_harness(
        const RideCostBreakdown(distanceKm: 20, lines: [])));
    await tester.pumpAndSettle();
    expect(find.text('Set up'), findsOneWidget);
    expect(find.text('RIDE COST'), findsNothing);
  });

  testWidgets('renders nothing while loading or for a zero-distance ride',
      (tester) async {
    await tester.pumpWidget(_harness(null));
    expect(find.byType(Card), findsNothing);
    expect(find.text('Set up'), findsNothing);

    await tester.pumpWidget(_harness(
        const RideCostBreakdown(distanceKm: 0, lines: []),
        distanceKm: 0));
    expect(find.text('Set up'), findsNothing);
  });
}
