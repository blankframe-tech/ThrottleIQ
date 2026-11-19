import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/check_details_sheet.dart';
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

  final forecast = CheckForecast(
    key: 'oilChange',
    serviceType: ServiceType.oilChange,
    kmLimit: 3000,
    baseKmLimit: 3000,
    kmSince: 2720,
    kmLeft: 280,
    daysLimit: 120,
    daysLeft: 12,
    lastServiceKm: 14000,
    lastServiceDate: DateTime.now().subtract(const Duration(days: 30)),
    status: ReminderStatus.dueSoon,
  );

  testWidgets(
      'CheckDetailsSheet displays wear countdown, progress, interval source and adaptive factors',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceConfigProvider.overrideWith(() => _FakeConfigs([
                const MaintenanceConfigEntity(
                  bikeId: 'b1',
                  serviceType: ServiceType.oilChange,
                  intervalKm: 3000,
                  intervalDays: 120,
                  source: IntervalSource.template,
                  isEnabled: true,
                ),
              ])),
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
                onPressed: () => CheckDetailsSheet.show(
                  ctx,
                  bike: bike,
                  forecast: forecast,
                  imperial: false,
                ),
                child: const Text('Open Check Details'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Check Details'));
    await tester.pumpAndSettle();

    // Verify title and subtitle
    expect(find.text('OIL CHANGE'), findsOneWidget);
    expect(
        find.text('Deep wear inspection, interval source & adaptive factors'),
        findsOneWidget);

    // Verify wear countdown & progress
    expect(find.textContaining('280 KM'), findsOneWidget);
    expect(find.textContaining('Interval: Every 3,000 km'), findsOneWidget);

    // Verify adaptive wear multipliers breakdown
    expect(find.text('ADAPTIVE WEAR MULTIPLIERS (THROTTLEIQ ENGINE)'),
        findsOneWidget);
    expect(find.textContaining('Dhaka metropolitan road dust'), findsOneWidget);
    expect(
        find.textContaining('Aggressive acceleration profile'), findsOneWidget);

    // Verify action buttons
    expect(find.text('⚡ LOG THIS SERVICE'), findsOneWidget);
    expect(find.text('CALIBRATE'), findsOneWidget);
  });
}

class _FakeConfigs extends MaintenanceConfigNotifier {
  _FakeConfigs(this._configs);
  final List<MaintenanceConfigEntity> _configs;
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async => _configs;
}
