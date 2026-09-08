import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/domain/calculators/auto_ride_reconciler.dart';
import 'package:throttleiq/features/ride/domain/calculators/ride_resume.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

void main() {
  sqfliteFfiInit();

  group('RideEntity.maxSpeedKmh physical invariants', () {
    test('returns 0 when speeds are null or zero', () {
      final ride = RideEntity(
        id: 'r1',
        userId: 'u1',
        bikeId: 'b1',
        startTime: DateTime(2026, 1, 1),
        maxSpeedMs: 0,
        avgSpeedMs: 0,
      );
      expect(ride.maxSpeedKmh, 0.0);
    });

    test('recovers from 0 top speed using average speed floor', () {
      final ride = RideEntity(
        id: 'r1',
        userId: 'u1',
        bikeId: 'b1',
        startTime: DateTime(2026, 1, 1),
        maxSpeedMs: 0,
        avgSpeedMs: 10.0, // 36 km/h
      );
      // Top speed must be at least average speed (36 km/h)
      expect(ride.maxSpeedKmh, 36.0);
    });

    test('heals inverted speeds (max < avg)', () {
      final ride = RideEntity(
        id: 'r1',
        userId: 'u1',
        bikeId: 'b1',
        startTime: DateTime(2026, 1, 1),
        maxSpeedMs: 5.0, // 18 km/h
        avgSpeedMs: 10.0, // 36 km/h
      );
      // Top speed cannot be lower than average speed
      expect(ride.maxSpeedKmh, 36.0);
    });

    test('preserves valid top speed greater than average', () {
      final ride = RideEntity(
        id: 'r1',
        userId: 'u1',
        bikeId: 'b1',
        startTime: DateTime(2026, 1, 1),
        maxSpeedMs: 25.0, // 90 km/h
        avgSpeedMs: 15.0, // 54 km/h
      );
      expect(ride.maxSpeedKmh, 90.0);
    });

    test('clamps impossible GPS speed glitch to max plausible speed (70 m/s = 252 km/h)', () {
      final ride = RideEntity(
        id: 'r1',
        userId: 'u1',
        bikeId: 'b1',
        startTime: DateTime(2026, 1, 1),
        maxSpeedMs: 150.0, // 540 km/h glitch
        avgSpeedMs: 15.0,
      );
      expect(ride.maxSpeedKmh, SensorConstants.maxPlausibleSpeedMs * 3.6);
    });
  });

  group('RideResume speed calculation', () {
    final t0 = DateTime.utc(2026, 5, 1, 9);

    StoredFix fix(int secondsIn, double latOffset, double speedMs) => (
          time: t0.add(Duration(seconds: secondsIn)),
          lat: 23.8103 + latOffset,
          lng: 90.4125,
          speedMs: speedMs,
        );

    test('derives speed when Doppler GPS speed is 0 m/s but coordinates move', () {
      // 0.001 deg lat ~= 111.2 m. In 10 seconds, this is ~11.12 m/s (~40 km/h)
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 0),
        fix(10, 0.001, 0),
        fix(20, 0.002, 0),
      ]);

      expect(aggregates.maxSpeedMs, greaterThan(10.0));
      expect(aggregates.maxSpeedMs, lessThan(15.0));
      expect(aggregates.speedCount, greaterThan(0));
      expect(aggregates.speedSum, greaterThan(0));
    });

    test('rejects stationary jitter (< 1.5m) when speedMs is 0', () {
      // 0.000005 deg ~= 0.55m in 5 seconds (stationary drift)
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 0),
        fix(5, 0.000005, 0),
      ]);

      expect(aggregates.maxSpeedMs, 0.0);
    });

    test('rejects impossible GPS teleportation spike (> 70 m/s derived speed)', () {
      // 0.01 deg lat ~= 1112m in 1 second = 1112 m/s jump
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 10),
        fix(1, 0.01, 0), // GPS teleportation
        fix(11, 0.011, 10),
      ]);

      expect(aggregates.maxSpeedMs, lessThanOrEqualTo(SensorConstants.maxPlausibleSpeedMs));
    });

    test('rejects impossible raw speed spike (> 70 m/s)', () {
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 15),
        fix(5, 0.0005, 180), // 648 km/h sensor glitch
        fix(10, 0.001, 16),
      ]);

      expect(aggregates.maxSpeedMs, lessThanOrEqualTo(SensorConstants.maxPlausibleSpeedMs));
      expect(aggregates.maxSpeedMs, closeTo(16.0, 1.0));
    });
  });

  group('AutoRideReconciler speed calculation', () {
    const mPerDegLat = 111320.0;

    test('reconciles ride and calculates valid top speed when GPS Doppler speed is 0', () {
      final reconciler = AutoRideReconciler();
      final t0 = DateTime(2026, 8, 16, 9);
      final fixes = <StagedFix>[];
      var lat = 23.8103;
      const lng = 90.4125;
      const speedMs = 15.0; // ~54 km/h

      // 120 seconds of riding northbound at 15 m/s with speedMs reported as 0.0
      for (var s = 0; s <= 120; s += 2) {
        fixes.add((
          timestamp: t0.add(Duration(seconds: s)),
          lat: lat,
          lng: lng,
          speedMs: 0.0, // Doppler chip returning 0
          accuracyM: 5.0,
          altitudeM: 10.0,
          headingDeg: 0.0,
        ));
        lat += (speedMs * 2) / mPerDegLat;
      }

      final outcome = reconciler.reconcile(fixes);
      expect(outcome.isAccepted, isTrue);
      expect(outcome.ride!.maxSpeedMs, greaterThan(12.0));
      expect(outcome.ride!.maxSpeedMs, lessThanOrEqualTo(SensorConstants.maxPlausibleSpeedMs));
      expect(outcome.ride!.avgSpeedMs, greaterThan(12.0));
    });

    test('caps speed spikes above 70 m/s during auto reconciliation', () {
      final reconciler = AutoRideReconciler();
      final t0 = DateTime(2026, 8, 16, 9);
      final fixes = <StagedFix>[];
      var lat = 23.8103;
      const lng = 90.4125;
      const normalSpeedMs = 15.0;

      for (var s = 0; s <= 120; s += 2) {
        final currentSpeed = (s == 60) ? 200.0 : normalSpeedMs; // glitch at 60s
        fixes.add((
          timestamp: t0.add(Duration(seconds: s)),
          lat: lat,
          lng: lng,
          speedMs: currentSpeed,
          accuracyM: 5.0,
          altitudeM: 10.0,
          headingDeg: 0.0,
        ));
        lat += (normalSpeedMs * 2) / mPerDegLat;
      }

      final outcome = reconciler.reconcile(fixes);
      expect(outcome.isAccepted, isTrue);
      expect(outcome.ride!.maxSpeedMs, lessThanOrEqualTo(SensorConstants.maxPlausibleSpeedMs));
    });
  });

  group('RideDao real SQLite speed healing', () {
    late Database db;
    final rideDao = RideDao();

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      DatabaseHelper.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('heals corrupted massive max speed (> 70 m/s) on query and updates DB', () async {
      await db.insert('rides', {
        'id': 'glitch-ride',
        'user_id': 'u1',
        'bike_id': 'b1',
        'start_time': DateTime(2026, 1, 1, 10).toIso8601String(),
        'distance_m': 5000.0,
        'duration_s': 300,
        'avg_speed_ms': 16.0,
        'max_speed_ms': 180.0, // 648 km/h impossible spike
        'status': 'completed',
        'synced': 1,
        'created_at': DateTime(2026, 1, 1, 10).toIso8601String(),
      });

      final rides = await rideDao.getAllForUser('u1');
      expect(rides, hasLength(1));
      final ride = rides.first;

      // Healed in memory to plausible fallback (avg * 1.5 = 24.0 m/s)
      expect(ride['max_speed_ms'], lessThanOrEqualTo(SensorConstants.maxPlausibleSpeedMs));
      expect(ride['max_speed_ms'], closeTo(24.0, 0.1));

      // Wait a tick for unawaited db.update to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify DB was updated
      final rows = await db.query('rides', where: 'id = ?', whereArgs: ['glitch-ride']);
      expect(rows.first['max_speed_ms'], closeTo(24.0, 0.1));
    });

    test('heals 0 top speed when distance and average speed exist', () async {
      await db.insert('rides', {
        'id': 'zero-top-ride',
        'user_id': 'u1',
        'bike_id': 'b1',
        'start_time': DateTime(2026, 1, 1, 10).toIso8601String(),
        'distance_m': 5000.0,
        'duration_s': 300,
        'avg_speed_ms': 16.67,
        'max_speed_ms': 0.0, // Claude bug: 0 top speed
        'status': 'completed',
        'synced': 1,
        'created_at': DateTime(2026, 1, 1, 10).toIso8601String(),
      });

      final ride = await rideDao.getById('zero-top-ride');
      expect(ride, isNotNull);
      // Top speed must be healed to at least average speed
      expect(ride!['max_speed_ms'], closeTo(16.67, 0.1));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final rows = await db.query('rides', where: 'id = ?', whereArgs: ['zero-top-ride']);
      expect(rows.first['max_speed_ms'], closeTo(16.67, 0.1));
    });

    test('heals inverted speeds where max_speed < avg_speed', () async {
      await db.insert('rides', {
        'id': 'inverted-ride',
        'user_id': 'u1',
        'bike_id': 'b1',
        'start_time': DateTime(2026, 1, 1, 10).toIso8601String(),
        'distance_m': 6000.0,
        'duration_s': 300,
        'avg_speed_ms': 20.0,
        'max_speed_ms': 10.0,
        'status': 'completed',
        'synced': 1,
        'created_at': DateTime(2026, 1, 1, 10).toIso8601String(),
      });

      final ride = await rideDao.getById('inverted-ride');
      expect(ride, isNotNull);
      expect(ride!['max_speed_ms'], greaterThanOrEqualTo(ride['avg_speed_ms'] as num));
    });
  });
}
