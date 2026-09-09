import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/edit_maintenance_check_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  Widget buildHarness({
    required MaintenanceConfigEntity config,
    required void Function(MaintenanceConfigEntity? result) onSheetClosed,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await EditMaintenanceCheckSheet.show(
                  context,
                  config: config,
                  persistImmediately: false,
                );
                onSheetClosed(result);
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders initial values for fuel maintenance item', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const config = MaintenanceConfigEntity(
      bikeId: 'bike-1',
      serviceType: ServiceType.fuel,
      intervalKm: 300,
      isEnabled: true,
      notes: 'Octane 95, 12L Tank',
    );

    await tester.pumpWidget(buildHarness(
      config: config,
      onSheetClosed: (_) {},
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('Octane 95, 12L Tank'), findsOneWidget);
    expect(find.text('Track on Dashboard'), findsOneWidget);
  });

  testWidgets('updates interval and extra specs on save', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const config = MaintenanceConfigEntity(
      bikeId: 'bike-1',
      serviceType: ServiceType.oilChange,
      intervalKm: 2500,
      isEnabled: true,
    );

    MaintenanceConfigEntity? saved;
    await tester.pumpWidget(buildHarness(
      config: config,
      onSheetClosed: (result) => saved = result,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Select 3000 km preset chip
    await tester.tap(find.text('3000 km'));
    await tester.pumpAndSettle();

    // Enter specifications notes in second TextFormField
    final notesField = find.byType(TextFormField).at(1);
    await tester.enterText(notesField, 'Motul 7100 10W-40 Full Synthetic');
    await tester.pumpAndSettle();

    // Tap Save button
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.intervalKm, 3000);
    expect(saved!.notes, 'Motul 7100 10W-40 Full Synthetic');
    expect(saved!.isEnabled, isTrue);
  });

  testWidgets('can disable tracking via switch', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const config = MaintenanceConfigEntity(
      bikeId: 'bike-1',
      serviceType: ServiceType.chain,
      intervalKm: 500,
      isEnabled: true,
      notes: 'Motul C2 Chain Lube',
    );

    MaintenanceConfigEntity? saved;
    await tester.pumpWidget(buildHarness(
      config: config,
      onSheetClosed: (result) => saved = result,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Toggle switch off
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Tap Save button
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.isEnabled, isFalse);
    expect(saved!.notes, 'Motul C2 Chain Lube');
  });
}
