import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/maintenance_config_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/edit_maintenance_check_sheet.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/maintenance_settings_section.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

const _oil = MaintenanceConfigEntity(
  bikeId: 'bike-1',
  serviceType: ServiceType.oilChange,
  intervalKm: 2000,
  isEnabled: true,
);

class _FakeConfigs extends MaintenanceConfigNotifier {
  @override
  Future<List<MaintenanceConfigEntity>> build(String bikeId) async => [_oil];
}

class _NoBikes extends GarageNotifier {
  @override
  Future<List<BikeEntity>> build() async => [];
}

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    );

void main() {
  // issues §101.R9: the km/mi segments were bare GestureDetectors with no
  // button role or selected state.
  testWidgets('unit toggle segments announce role and selection',
      (tester) async {
    final handle = tester.ensureSemantics();
    bool? changedTo;
    await tester.pumpWidget(_app(Scaffold(
      body: Center(
        child: MaintenanceUnitToggle(
          imperial: true,
          onChanged: (v) => changedTo = v,
        ),
      ),
    )));

    expect(
      tester.getSemantics(find.text('mi')),
      matchesSemantics(
        label: 'mi',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );

    // The semantics tap reaches the callback.
    expect(tester.getSemantics(find.text('km')),
        isSemantics(isButton: true, isSelected: false));
    tester.semantics.tap(find.semantics.byLabel('km'));
    expect(changedTo, isFalse);
    handle.dispose();
  });

  group('maintenance config edit pill (issues §101.R9)', () {
    Future<void> pumpConfig(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        const MaintenanceConfigScreen(bikeId: 'bike-1'),
        overrides: [
          maintenanceConfigProvider.overrideWith(_FakeConfigs.new),
          garageProvider.overrideWith(_NoBikes.new),
        ],
      ));
      await tester.pumpAndSettle();
    }

    final pill = find.byKey(ValueKey('maint-config-edit-${_oil.key}'));

    testWidgets('has a 48dp hit area', (tester) async {
      await pumpConfig(tester);
      expect(pill, findsOneWidget);
      final size = tester.getSize(pill);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('a tap just above the visible pill opens edit, not toggle',
        (tester) async {
      await pumpConfig(tester);
      final checkbox = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);

      // The visible pill is ~22dp tall; 18dp above its centre is outside
      // it but inside the 48dp hit box.
      await tester.tapAt(tester.getCenter(pill) - const Offset(0, 18));
      await tester.pumpAndSettle();

      expect(find.byType(EditMaintenanceCheckSheet), findsOneWidget);
      expect(tester.widget<Checkbox>(checkbox.first).value, isTrue);
    });
  });
}
