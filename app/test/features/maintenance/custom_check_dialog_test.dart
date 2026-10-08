import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/catalog/schedule_templates.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/maintenance_config_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R10: the "add custom check" dialog must scroll with the
/// keyboard open on a small screen, and must not dispose its controllers
/// while it is still animating out.
void main() {
  final bike = BikeEntity(
    id: 'b1',
    userId: 'u1',
    brand: 'Bajaj',
    model: 'Pulsar 150',
    createdAt: DateTime(2025, 1, 1),
  );
  final configs = configsFromTemplate(
      bikeId: 'b1', template: templateById('bajaj_pulsar_150'));

  testWidgets('small screen + keyboard: no overflow, closes cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(480, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const MaintenanceConfigScreen(bikeId: 'b1')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        garageProvider.overrideWith(() => _Garage([bike])),
        maintenanceConfigProvider.overrideWith(() => _Configs(configs)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
          child: child!,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ));
    await tester.pumpAndSettle();

    final add = find.text('Add your own check');
    await tester.scrollUntilVisible(add, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).first, 'Radiator flush');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    // Pump through the exit animation frame by frame: a controller disposed
    // too early throws here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
  });
}

class _Garage extends GarageNotifier {
  _Garage(this._bikes);
  final List<BikeEntity> _bikes;
  @override
  Future<List<BikeEntity>> build() async => _bikes;
}

class _Configs extends MaintenanceConfigNotifier {
  _Configs(this._configs);
  final List<MaintenanceConfigEntity> _configs;
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async => _configs;
}
