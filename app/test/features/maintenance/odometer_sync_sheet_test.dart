import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/odometer_sync_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R7.
class _Garage extends GarageNotifier {
  _Garage({this.result, this.fail = false});
  final double? result;
  final bool fail;
  int calls = 0;

  @override
  Future<List<BikeEntity>> build() async => const [];

  @override
  Future<double?> syncOdometer({
    required String bikeId,
    required double newOdometerKm,
  }) async {
    calls++;
    if (fail) throw StateError('db locked');
    return result ?? newOdometerKm;
  }
}

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Yamaha',
  model: 'MT-15',
  totalDistanceM: 5000000, // 5000 km tracked
  odometerKm: 100,
  createdAt: DateTime(2024, 1, 1),
);

Future<void> _open(WidgetTester tester, _Garage garage) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [garageProvider.overrideWith(() => garage)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => OdometerSyncSheet.show(context, _bike),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder get _confirm => find.byType(ElevatedButton);

Future<void> _confirmTap(WidgetTester tester) async {
  await tester.ensureVisible(_confirm);
  await tester.tap(_confirm);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('snackbar shows the odometer that actually stuck',
      (tester) async {
    final garage = _Garage(result: 5000);
    await _open(tester, garage);
    await tester.enterText(find.byType(TextFormField), '5400');
    await _confirmTap(tester);
    expect(garage.calls, 1);
    expect(find.text('Odometer synced to 5000 km!'), findsOneWidget);
    expect(find.text('Odometer synced to 5400 km!'), findsNothing);
  });

  testWidgets('a reading below the tracked km is rejected', (tester) async {
    final garage = _Garage();
    await _open(tester, garage);
    await tester.enterText(find.byType(TextFormField), '3000');
    await _confirmTap(tester);
    expect(garage.calls, 0);
    expect(find.text('Enter valid positive number'), findsOneWidget);
  });

  testWidgets('a throwing save re-enables the confirm button', (tester) async {
    final garage = _Garage(fail: true);
    await _open(tester, garage);
    await tester.enterText(find.byType(TextFormField), '5400');
    await _confirmTap(tester);
    expect(garage.calls, 1);
    expect(find.text("Couldn't sync the odometer. Please try again."),
        findsOneWidget);
    expect(tester.widget<ElevatedButton>(_confirm).onPressed, isNotNull);
  });
}
