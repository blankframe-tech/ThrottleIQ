@Timeout(Duration(seconds: 20))
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';

class _MockUser extends Mock implements User {
  @override
  String get uid => 'u1';
}

/// issues §101.R10 (addBike active) and §101.R7 (syncOdometer result),
/// against a real in-memory schema.
void main() {
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('bikes', {
      'id': 'old',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar',
      'is_active': 1,
      'total_distance_m': 5000000.0,
      'odometer_km': 100.0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(_MockUser())]);
    addTearDown(c.dispose);
    return c;
  }

  test('addBike with the garage unloaded leaves the active bike active',
      () async {
    final c = container();
    // Deliberately never read garageProvider: its state is still null.
    final id = await c
        .read(garageProvider.notifier)
        .addBike(brand: 'Honda', model: 'CB');
    expect(id, isNotNull);
    final rows = await db.query('bikes', orderBy: 'id');
    final active = rows.where((r) => r['is_active'] == 1).map((r) => r['id']);
    expect(active, ['old']);
  });

  test('the first bike becomes active', () async {
    await db.delete('bikes');
    final c = container();
    final id = await c
        .read(garageProvider.notifier)
        .addBike(brand: 'Honda', model: 'CB');
    final rows = await db.query('bikes');
    expect(rows.single['id'], id);
    expect(rows.single['is_active'], 1);
  });

  test('syncOdometer returns the odometer the bike really shows', () async {
    final c = container();
    await c.read(garageProvider.future);
    final n = c.read(garageProvider.notifier);
    // Tracked total is 5000 km; a reading of 3000 can't go below it.
    expect(await n.syncOdometer(bikeId: 'old', newOdometerKm: 3000), 5000);
    expect(await n.syncOdometer(bikeId: 'old', newOdometerKm: 7000), 7000);
    expect(await n.syncOdometer(bikeId: 'nope', newOdometerKm: 1), isNull);
  });

  test('syncOdometer measures against km credited after the sheet opened',
      () async {
    final c = container();
    await c.read(garageProvider.future);
    // Auto-tracking credits 3 km while the sync sheet is open.
    await db.rawUpdate(
        'UPDATE bikes SET total_distance_m = total_distance_m + 3000');

    final shown = await c
        .read(garageProvider.notifier)
        .syncOdometer(bikeId: 'old', newOdometerKm: 7000);

    final r = (await db.query('bikes')).single;
    expect(r['total_distance_m'], 5003000.0);
    // Baseline + the 5003 tracked km reads exactly what the rider typed.
    expect(r['odometer_km'], closeTo(1997, 1e-9));
    expect(shown, closeTo(7000, 1e-9));
  });

  group('updateBike writes only the edited columns (critique oct27 #7)', () {
    Future<Map<String, Object?>> row() async =>
        (await db.query('bikes', where: 'id = ?', whereArgs: ['old'])).single;

    test('km credited after the screen loaded survive a save', () async {
      final c = container();
      final loaded = (await c.read(garageProvider.future)).single;
      // Auto-tracking credits 12 km and a ride lands while Edit Bike is open.
      await db.rawUpdate('''UPDATE bikes SET odometer_km = odometer_km + 12,
          total_distance_m = total_distance_m + 3000, ride_count = 4,
          last_ride_at = '2026-10-27T08:00:00.000Z', synced = 1''');

      await c
          .read(garageProvider.notifier)
          .updateBike(loaded.copyWith(brand: 'TVS', model: 'Apache'));

      final r = await row();
      expect(r['brand'], 'TVS');
      expect(r['model'], 'Apache');
      expect(r['odometer_km'], 112.0);
      expect(r['total_distance_m'], 5003000.0);
      expect(r['ride_count'], 4);
      expect(r['last_ride_at'], '2026-10-27T08:00:00.000Z');
      expect(r['is_active'], 1);
      expect(r['synced'], 0);
    });

    test('a typed reading becomes a baseline against the km stored now',
        () async {
      final c = container();
      final loaded = (await c.read(garageProvider.future)).single;
      await db.rawUpdate(
          'UPDATE bikes SET total_distance_m = total_distance_m + 3000');

      final n = c.read(garageProvider.notifier);
      await n.updateBike(loaded, odometerReadingKm: 6000);
      expect((await row())['odometer_km'], closeTo(997, 1e-9));

      // Below the tracked km: floored at 0. Cleared: null.
      await n.updateBike(loaded, odometerReadingKm: 10);
      expect((await row())['odometer_km'], 0.0);
      await n.updateBike(loaded, clearOdometer: true);
      expect((await row())['odometer_km'], isNull);
    });
  });
}
