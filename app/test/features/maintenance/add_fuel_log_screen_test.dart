import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/fuel_provider.dart';
import 'package:throttleiq/features/maintenance/presentation/screens/add_fuel_log_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

final _now = DateTime(2026, 10, 9, 15);

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Bajaj',
  model: 'Pulsar 150',
  odometerKm: 12000,
  totalDistanceM: 345 * 1000,
  createdAt: DateTime(2025, 1, 1),
);

FuelLogEntity _log(String id, DateTime at, double odo, {bool full = true}) =>
    FuelLogEntity(
      id: id,
      bikeId: 'b1',
      filledAt: at,
      odometerKm: odo,
      liters: 6,
      totalCost: 780,
      pricePerLiter: 130,
      fullTank: full,
      station: 'Meghna',
      createdAt: at,
      updatedAt: at,
    );

class _Garage extends GarageNotifier {
  @override
  Future<List<BikeEntity>> build() async => [_bike];
}

class _Logs extends FuelLogsNotifier {
  _Logs(this._logs);
  final List<FuelLogEntity> _logs;
  final saved = <(FuelLogDraft, String?)>[];

  @override
  Future<List<FuelLogEntity>> build(String bikeId) async => _logs;

  @override
  Future<String> save(FuelLogDraft d, {String? id}) async {
    saved.add((d, id));
    return id ?? 'new';
  }
}

void main() {
  late _Logs logs;

  Future<void> pump(WidgetTester tester,
      {List<FuelLogEntity> existing = const [], String? logId}) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    logs = _Logs(existing);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'fuel',
                builder: (_, __) =>
                    AddFuelLogScreen(bikeId: 'b1', logId: logId, now: _now)),
          ]),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        garageProvider.overrideWith(_Garage.new),
        allBikesProvider.overrideWith((ref) async => [_bike]),
        fuelLogsProvider.overrideWith(() => logs),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ));
    router.push('/fuel');
    await tester.pumpAndSettle();
  }

  String text(WidgetTester t, String key) =>
      t.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('fuelSave')));
    await tester.tap(find.byKey(const Key('fuelSave')));
    await tester.pumpAndSettle();
  }

  testWidgets('prefills the odometer from the bike', (tester) async {
    await pump(tester);
    expect(text(tester, 'fuelOdometer'), '12345');
  });

  testWidgets('total paid fills in the price per litre and saves',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('fuelLiters')), '5');
    await tester.enterText(find.byKey(const Key('fuelTotal')), '650');
    await tester.pump();
    expect(text(tester, 'fuelPrice'), '130');
    await tapSave(tester);
    final (d, id) = logs.saved.single;
    expect(id, isNull);
    expect(d.liters, 5);
    expect(d.totalCost, 650);
    expect(d.pricePerLiter, 130);
    expect(d.odometerKm, 12345);
    expect(d.fullTank, isTrue);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('price per litre (Bangla digits, comma grouping) gives the total',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('fuelOdometer')), '১২,৫০০');
    await tester.enterText(find.byKey(const Key('fuelLiters')), '4');
    await tester.enterText(find.byKey(const Key('fuelPrice')), '125.5');
    await tester.pump();
    expect(text(tester, 'fuelTotal'), '502');
    await tester.tap(find.byKey(const Key('fuelFullTank')));
    await tester.pump();
    await tapSave(tester);
    final (d, _) = logs.saved.single;
    expect(d.odometerKm, 12500);
    expect(d.totalCost, 502);
    expect(d.pricePerLiter, 125.5);
    expect(d.fullTank, isFalse);
  });

  testWidgets('litres and some money are required', (tester) async {
    await pump(tester);
    await tapSave(tester);
    expect(find.text('Required'), findsOneWidget);
    expect(
        find.text('Enter the total or the price per litre'), findsNWidgets(2));
    expect(logs.saved, isEmpty);
  });

  testWidgets('an odometer below an earlier fill-up is rejected',
      (tester) async {
    await pump(tester, existing: [_log('a', DateTime(2026, 10, 1), 12400)]);
    await tester.enterText(find.byKey(const Key('fuelOdometer')), '12300');
    await tester.enterText(find.byKey(const Key('fuelLiters')), '5');
    await tester.enterText(find.byKey(const Key('fuelTotal')), '650');
    await tapSave(tester);
    expect(
        find.text("Lower than an earlier fill-up's odometer"), findsOneWidget);
    expect(logs.saved, isEmpty);
  });

  testWidgets('editing loads the fill-up and saves under its id',
      (tester) async {
    final existing = _log('a', DateTime(2026, 10, 1, 8), 12400, full: false);
    await pump(tester, existing: [existing], logId: 'a');
    expect(find.text('Edit fill-up'), findsOneWidget);
    expect(text(tester, 'fuelOdometer'), '12400');
    expect(text(tester, 'fuelLiters'), '6');
    expect(text(tester, 'fuelTotal'), '780');
    await tester.enterText(find.byKey(const Key('fuelLiters')), '6.5');
    await tester.pump();
    expect(text(tester, 'fuelPrice'), '120');
    await tapSave(tester);
    final (d, id) = logs.saved.single;
    expect(id, 'a');
    expect(d.filledAt, existing.filledAt);
    expect(d.fullTank, isFalse);
    expect(d.station, 'Meghna');
  });
}
