import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

/// Schema v26: per-ride lean / g-force peaks and elevation gain/loss.
/// Nullable columns, NULL on legacy rides, dropped from the cloud payload
/// when NULL.
const _v26 = [
  'max_lean_deg',
  'peak_lateral_g',
  'peak_accel_g',
  'peak_brake_g',
  'elevation_gain_m',
  'elevation_loss_m',
];

void main() {
  sqfliteFfiInit();

  group('v26 migration', () {
    late Database db;
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    });
    tearDown(() => db.close());

    test('schemaVersion is 26 or later', () {
      expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(26));
    });

    test('fresh schema has every v26 column, nullable with no default',
        () async {
      await DatabaseHelper.instance.createSchemaForTesting(db);
      final cols = await db.rawQuery('PRAGMA table_info(rides)');
      for (final name in _v26) {
        final col = cols.firstWhere((c) => c['name'] == name,
            orElse: () => throw StateError('missing $name'));
        expect(col['type'], 'REAL', reason: name);
        expect(col['notnull'], 0, reason: name);
        expect(col['dflt_value'], isNull, reason: name);
      }
    });

    test('25 → 26 adds the columns, leaves legacy rides NULL, re-runnable',
        () async {
      // A v25 `rides` table: the fresh-install DDL minus the v26 columns.
      await db.execute('''
        CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          bike_id TEXT NOT NULL, start_time TEXT NOT NULL,
          distance_m REAL NOT NULL DEFAULT 0,
          hard_brake_count INTEGER NOT NULL DEFAULT 0,
          rapid_accel_count INTEGER NOT NULL DEFAULT 0,
          high_jerk_count INTEGER NOT NULL DEFAULT 0,
          overspeed_count INTEGER,
          status TEXT NOT NULL DEFAULT 'active', created_at TEXT NOT NULL)
      ''');
      await db.insert('rides', {
        'id': 'old',
        'user_id': 'u',
        'bike_id': 'b',
        'start_time': '2026-01-01',
        'status': 'completed',
        'created_at': '2026-01-01',
      });
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 25, 26);
      // Idempotent: a second run must not throw on the existing columns.
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 25, 26);

      final r = (await db.query('rides')).single;
      for (final name in _v26) {
        expect(r.containsKey(name), isTrue, reason: name);
        expect(r[name], isNull, reason: name);
      }
      final e = RideModel.fromMap(r);
      expect(e.maxLeanDeg, isNull);
      expect(e.peakLateralG, isNull);
      expect(e.peakAccelG, isNull);
      expect(e.peakBrakeG, isNull);
      expect(e.elevationGainM, isNull);
      expect(e.elevationLossM, isNull);
    });

    test('an upgrade stopping at 25 does not touch rides', () async {
      // The older migration tests build no `rides` table; the v26 step is
      // gated on newVersion so they keep passing.
      await db.execute('CREATE TABLE bikes (id TEXT PRIMARY KEY)');
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 25, 25);
    });
  });

  group('RideModel round-trip', () {
    Map<String, dynamic> row([Map<String, Object?> extra = const {}]) => {
          'id': 'r',
          'user_id': 'u',
          'bike_id': 'b',
          'start_time': '2026-10-01T08:00:00.000',
          'distance_m': 1000.0,
          'hard_brake_count': 0,
          'rapid_accel_count': 0,
          'high_jerk_count': 0,
          'status': 'completed',
          ...extra,
        };

    test('absent columns read as null', () {
      final e = RideModel.fromMap(row());
      expect(e.maxLeanDeg, isNull);
      expect(e.elevationGainM, isNull);
    });

    test('values survive fromMap → toMap → copyWith', () {
      final e = RideModel.fromMap(row({
        'max_lean_deg': 31.5,
        'peak_lateral_g': 0.61,
        'peak_accel_g': 0.32,
        // An INTEGER-typed value from a cloud doc still reads as a double.
        'peak_brake_g': 1,
        'elevation_gain_m': 120.0,
        'elevation_loss_m': 95.5,
      }));
      expect(e.maxLeanDeg, 31.5);
      expect(e.peakLateralG, 0.61);
      expect(e.peakAccelG, 0.32);
      expect(e.peakBrakeG, 1.0);
      expect(e.elevationGainM, 120.0);
      expect(e.elevationLossM, 95.5);

      final m = RideModel.toMap(e);
      expect(m['max_lean_deg'], 31.5);
      expect(m['peak_lateral_g'], 0.61);
      expect(m['peak_accel_g'], 0.32);
      expect(m['peak_brake_g'], 1.0);
      expect(m['elevation_gain_m'], 120.0);
      expect(m['elevation_loss_m'], 95.5);

      final c = e.copyWith(distanceM: 5);
      expect(c.maxLeanDeg, 31.5);
      expect(c.elevationLossM, 95.5);
      expect(e.copyWith(maxLeanDeg: 40).maxLeanDeg, 40);
    });

    test('a new RideEntity defaults every v26 field to unknown', () {
      final e = RideEntity(
          id: 'r', userId: 'u', bikeId: 'b', startTime: DateTime(2026));
      expect(e.maxLeanDeg, isNull);
      expect(e.peakLateralG, isNull);
      expect(e.peakAccelG, isNull);
      expect(e.peakBrakeG, isNull);
      expect(e.elevationGainM, isNull);
      expect(e.elevationLossM, isNull);
    });
  });

  test('ridePayload drops each NULL v26 field but keeps real ones', () {
    final payload = CloudRepository.ridePayload({
      'id': 'r',
      'max_lean_deg': null,
      'peak_lateral_g': null,
      'peak_accel_g': null,
      'peak_brake_g': null,
      'elevation_gain_m': 0.0,
      'elevation_loss_m': 12.0,
    });
    for (final k in ['max_lean_deg', 'peak_lateral_g', 'peak_accel_g']) {
      expect(payload, isNot(contains(k)));
    }
    expect(payload, isNot(contains('peak_brake_g')));
    // A measured flat ride (0 m) is real data, not "unknown".
    expect(payload, containsPair('elevation_gain_m', 0.0));
    expect(payload, containsPair('elevation_loss_m', 12.0));
    expect(CloudRepository.rideV26PayloadKeys, unorderedEquals(_v26));
  });
}
