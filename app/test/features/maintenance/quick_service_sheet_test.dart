import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/service_visit.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/quick_service_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  final bike = BikeEntity(
    id: 'b1',
    userId: 'u1',
    brand: 'Yamaha',
    model: 'MT-15',
    odometerKm: 14250,
    totalDistanceM: 0,
    createdAt: DateTime(2025, 1, 1),
  );

  testWidgets(
      'QuickServiceSheet displays pre-filled odo, bundles, chips, and submits',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageProvider.overrideWith(() => _FakeGarage([bike])),
          maintenanceProvider.overrideWith(() => _FakeLogs([])),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('bn')],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickServiceSheet.show(
                  ctx,
                  bike: bike,
                  initialTitle: 'Engine Oil',
                  initialCost: 650,
                  initialServiceType: ServiceType.oilChange,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify title and header
    expect(find.textContaining('LOG SERVICE: ENGINE OIL'), findsOneWidget);
    expect(find.text('1-tap service completion, bundles & receipt snap'),
        findsOneWidget);

    // Verify bundles chips
    expect(find.text('Oil + Filter'), findsOneWidget);
    expect(find.text('Chain Service'), findsOneWidget);
    expect(find.text('1st Free Service'), findsNothing); // wrong #n for most
    expect(find.text('Full Overhaul'), findsOneWidget);

    // Verify prefilled odometer is 14250
    expect(
      tester
          .widget<TextFormField>(
              find.byKey(const Key('quickServiceOdometerField')))
          .controller
          ?.text,
      '14250',
    );
    expect(find.text('Current (14250)'), findsOneWidget);

    // Test odometer delta increment chip (+50 km)
    await tester.ensureVisible(find.text('+50 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+50 km'));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(
              find.byKey(const Key('quickServiceOdometerField')))
          .controller
          ?.text,
      '14300',
    );

    // Test odometer reset chip back to current
    await tester.ensureVisible(find.text('Current (14250)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Current (14250)'));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(
              find.byKey(const Key('quickServiceOdometerField')))
          .controller
          ?.text,
      '14250',
    );

    // Test selecting a different bundle: Chain Service
    await tester.tap(find.text('Chain Service'));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('quickServiceCostField')))
          .controller
          ?.text,
      '650', // a bundle never invents a price
    );

    // Test quick cost chip (৳1,200)
    await tester.tap(find.text('৳1,200'));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('quickServiceCostField')))
          .controller
          ?.text,
      '1200',
    );

    // Submit via rapid confirmation button
    await tester.tap(find.byKey(const Key('quickServiceConfirmButton')));
    await tester.pumpAndSettle();

    // Sheet should be dismissed
    expect(find.byKey(const Key('quickServiceConfirmButton')), findsNothing);
  });

  testWidgets('starts empty, saves nothing invented, warns on a low odometer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final logs = _FakeLogs([
      MaintenanceEntity(
        id: 'l1',
        bikeId: 'b1',
        serviceType: ServiceType.oilChange,
        date: DateTime(2025, 6, 1),
        odometerKm: 20000,
        createdAt: DateTime(2025, 6, 1),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageProvider.overrideWith(() => _FakeGarage([bike])),
          maintenanceProvider.overrideWith(() => logs),
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
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickServiceSheet.show(ctx, bike: bike),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    String text(String key) =>
        tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
    expect(text('quickServiceCostField'), isEmpty);
    expect(find.text('Yamaha Authorized Service, Tejgaon'), findsNothing);
    // The bike reads 14,250 but an earlier visit says 20,000.
    expect(find.textContaining('Lower than an earlier visit'), findsOneWidget);
  });
}

class _FakeGarage extends GarageNotifier {
  _FakeGarage(this._bikes);
  final List<BikeEntity> _bikes;
  @override
  Future<List<BikeEntity>> build() async => _bikes;

  @override
  Future<double?> syncOdometer({
    required String bikeId,
    required double newOdometerKm,
  }) async {
    return newOdometerKm;
  }
}

class _FakeLogs extends MaintenanceNotifier {
  _FakeLogs(this._logs);
  final List<MaintenanceEntity> _logs;
  @override
  Future<List<MaintenanceEntity>> build(String bikeId) async => _logs;

  @override
  Future<String> saveVisit(VisitDraft draft) async {
    return 'v1';
  }
}
