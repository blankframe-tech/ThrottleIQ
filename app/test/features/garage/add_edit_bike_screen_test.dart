import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/garage/presentation/screens/add_edit_bike_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R1/R2: edit shows the dashboard reading (baseline + tracked
/// km) and saves it back as a baseline; bad numbers are rejected; editing
/// before the garage has loaded never creates a duplicate bike.
class _FakeGarage extends GarageNotifier {
  _FakeGarage(this.bikes, {this.gate});
  final List<BikeEntity> bikes;
  final Completer<void>? gate;
  final updated = <BikeEntity>[];
  int added = 0;

  @override
  Future<List<BikeEntity>> build() async {
    if (gate != null) await gate!.future;
    return bikes;
  }

  @override
  Future<void> updateBike(BikeEntity bike) async => updated.add(bike);

  @override
  Future<String?> addBike({
    required String brand,
    required String model,
    int? year,
    int? cc,
    String? imagePath,
    double? odometerKm,
    int? colorValue,
    bool isEbike = false,
  }) async {
    added++;
    return 'new';
  }
}

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Yamaha',
  model: 'MT-15',
  totalDistanceM: 500000,
  odometerKm: 1000,
  createdAt: DateTime(2024, 1, 1),
);

Future<_FakeGarage> _pump(WidgetTester tester, {Completer<void>? gate}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final fake = _FakeGarage([_bike], gate: gate);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
    GoRoute(
        path: '/edit',
        builder: (_, __) => const AddEditBikeScreen(bikeId: 'b1')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      garageProvider.overrideWith(() => fake),
      currentUserProvider.overrideWithValue(null),
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
  router.push('/edit');
  if (gate == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
  return fake;
}

Finder get _odoField => find.byType(TextFormField).last;
Finder get _save => find.byType(ElevatedButton).first;

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_save);
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edit shows baseline + tracked km and saves back a baseline',
      (tester) async {
    final fake = await _pump(tester);
    expect(tester.widget<TextFormField>(_odoField).controller!.text, '1500');

    await tester.enterText(_odoField, '1600');
    await _tapSave(tester);

    expect(fake.updated, hasLength(1));
    expect(fake.updated.single.odometerKm, 1100);
    expect(fake.added, 0);
  });

  testWidgets('untouched odometer keeps the stored baseline', (tester) async {
    final fake = await _pump(tester);
    await _tapSave(tester);
    expect(fake.updated.single.odometerKm, 1000);
  });

  testWidgets('rejects a reading below the tracked km and junk numbers',
      (tester) async {
    final fake = await _pump(tester);
    for (final bad in ['100', '-5', 'NaN', 'Infinity']) {
      await tester.enterText(_odoField, bad);
      await _tapSave(tester);
      expect(find.text('Invalid number'), findsWidgets, reason: bad);
    }
    expect(fake.updated, isEmpty);
  });

  testWidgets('cc above 3000 is rejected', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(find.byType(TextFormField).at(find.byType(TextFormField).evaluate().length - 2), '5000');
    await _tapSave(tester);
    expect(find.text('Invalid number'), findsWidgets);
    expect(fake.updated, isEmpty);
  });

  testWidgets('saving while the garage is still loading edits, not adds',
      (tester) async {
    final gate = Completer<void>();
    final fake = await _pump(tester, gate: gate);
    // Brand/model are required, so the rider typed them before the garage
    // finished loading.
    await tester.enterText(find.byType(TextFormField).at(0), 'Yamaha');
    await tester.enterText(find.byType(TextFormField).at(1), 'MT-15');
    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.pump();
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(fake.added, 0);
    expect(fake.updated, hasLength(1));
  });
}
