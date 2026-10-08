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
}
