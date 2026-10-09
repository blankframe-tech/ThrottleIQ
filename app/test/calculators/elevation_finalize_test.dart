import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/daos/ride_point_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/models/ride_model.dart';
import 'package:throttleiq/features/ride/domain/calculators/cornering_estimator.dart';
import 'package:throttleiq/features/ride/domain/calculators/elevation_profile.dart';
import 'package:throttleiq/features/ride/domain/calculators/final_ride_stats.dart';

/// Elevation (and the lean/g peaks) written once at ride finalize: the same
/// path stopRide takes — altitudes read from the stored points, through
/// [rideElevationGainLoss], into [buildFinalRideStats], onto the row.
void main() {
  sqfliteFfiInit();

  group('rideElevationGainLoss', () {
    test('a climb and descent match elevationGainLoss', () {
      final alts = <double?>[
        for (var i = 0; i < 20; i++) 10.0 + i * 2,
        for (var i = 0; i < 20; i++) 48.0 - i,
      ];
      final stored = rideElevationGainLoss(alts)!;
      final shown = elevationGainLoss(alts)!;
      expect(stored.gainM, shown.gainM);
      expect(stored.lossM, shown.lossM);
      expect(stored.gainM, greaterThan(30));
    });

    test('flat but well-sampled is a measured 0, not unknown', () {
      final alts = <double?>[for (var i = 0; i < 30; i++) 20.0 + (i % 2)];
      expect(elevationGainLoss(alts), isNull);
      final r = rideElevationGainLoss(alts)!;
      expect(r.gainM, 0);
      expect(r.lossM, 0);
    });

    test('too few or mostly-missing samples stay unknown', () {
      expect(rideElevationGainLoss(const []), isNull);
      expect(rideElevationGainLoss(const [1.0, 2.0, 3.0]), isNull);
      expect(
          rideElevationGainLoss(
              [for (var i = 0; i < 30; i++) i.isEven ? null : null]),
          isNull);
      expect(
          rideElevationGainLoss(
              [for (var i = 0; i < 30; i++) i % 3 == 0 ? i * 5.0 : null]),
          isNull);
    });
  });

  group('finalize persists elevation and peaks', () {
    late Database db;
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await db.insert('rides', {
        'id': 'r1',
        'user_id': 'u',
        'bike_id': 'b',
        'start_time': '2026-10-09T08:00:00.000',
        'status': 'active',
        'created_at': '2026-10-09T08:00:00.000',
      });
    });
    tearDown(() async {
      DatabaseHelper.overrideDatabaseForTesting(null);
      await db.close();
    });

    Map<String, dynamic> stats({
      ({double gainM, double lossM})? elevation,
      CorneringPeaks? peaks,
    }) =>
        buildFinalRideStats(
          endTime: DateTime(2026, 10, 9, 9),
          distanceM: 10000,
          maxSpeedMs: 20,
          speedSum: 100,
          speedCount: 10,
          movingMilliseconds: 600000,
          movingSeconds: 600,
          durationSeconds: 700,
          hardBrakeCount: 0,
          rapidAccelCount: 0,
          highJerkCount: 0,
          overspeedCount: 0,
          corneringPeaks: peaks,
          elevation: elevation,
        );

    test('points → altitudes → stats → row', () async {
      final start = DateTime(2026, 10, 9, 8);
      await RidePointDao().insertBatch([
        for (var i = 0; i < 40; i++)
          {
            'ride_id': 'r1',
            'timestamp': start.add(Duration(seconds: i)).toIso8601String(),
            'lat': 23.8,
            'lng': 90.4,
            'speed_ms': 10.0,
            // Up 1 m/s for 20 s, then down 0.5 m/s.
            'altitude_m': i < 20 ? 10.0 + i : 29.0 - (i - 20) * 0.5,
          },
      ]);
      final alts = await RidePointDao().getAltitudesForRide('r1');
      expect(alts, hasLength(40));
      final elevation = rideElevationGainLoss(alts);
      expect(elevation, isNotNull);

      await RideDao().finalizeRide(
        'r1',
        stats(
          elevation: elevation,
          peaks: const CorneringPeaks(
            maxLeanDeg: 28,
            maxLeanLeftDeg: 28,
            maxLeanRightDeg: 21,
            peakLateralG: 0.53,
            peakAccelG: 0.3,
            peakBrakeG: 0.6,
          ),
        ),
      );
      final ride = RideModel.fromMap((await RideDao().getById('r1'))!);
      expect(ride.elevationGainM, closeTo(elevation!.gainM, 1e-9));
      expect(ride.elevationLossM, closeTo(elevation.lossM, 1e-9));
      expect(ride.elevationGainM, greaterThan(15));
      expect(ride.elevationLossM, greaterThan(5));
      expect(ride.maxLeanDeg, 28);
      expect(ride.peakLateralG, 0.53);
      expect(ride.peakAccelG, 0.3);
      expect(ride.peakBrakeG, 0.6);
    });

    test('no elevation leaves the columns NULL for the backfill', () async {
      final s = stats();
      expect(s.containsKey('elevation_gain_m'), isFalse);
      expect(s['max_lean_deg'], isNull);
      await RideDao().finalizeRide('r1', s);
      final ride = RideModel.fromMap((await RideDao().getById('r1'))!);
      expect(ride.elevationGainM, isNull);
      expect(ride.maxLeanDeg, isNull);
    });
  });
}
