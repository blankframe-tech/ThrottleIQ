@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/auto_detection_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/maintenance/data/repositories/maintenance_forecast_repository.dart';
import 'package:throttleiq/features/ride/data/repositories/detected_odometer_credit.dart';

/// issues §93.1 (decided 2026-10-06): forgotten rides count toward the bike's
/// odometer — once, only the part no recorded ride covers, only when it
/// looks like riding.
void main() {
  sqfliteFfiInit();
  late Database db;
  final dao = AutoDetectionDao();
  final t0 = DateTime(2026, 10, 5, 8);

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    for (final (id, active) in [('b1', 1), ('b2', 0)]) {
      await db.insert('bikes', {
        'id': id,
        'user_id': 'u1',
        'brand': 'Bajaj',
        'model': 'Pulsar',
        'is_active': active,
        'odometer_km': 1000.0,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      });
    }
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  /// A straight run north at ~36 km/h, one fix every 5 s: 50 m per fix.
  Future<void> seedTrip(String id, {int fixes = 60, DateTime? start}) async {
    final s = start ?? t0;
    await dao.insertDetection(
        id: id, startedAt: s, triggerSource: 'activity', userId: 'u1');
    for (var i = 0; i < fixes; i++) {
      await dao.appendFix(
        detectionId: id,
        timestamp: s.add(Duration(seconds: 5 * i)),
        lat: 23.8 + i * 0.00045, // ≈ 50 m
        lng: 90.4,
        speedMs: 10,
        accuracyM: 5,
      );
    }
  }

  Future<double> odometer(String bike) async =>
      ((await db.query('bikes', where: 'id = ?', whereArgs: [bike]))
              .single['odometer_km'] as num)
          .toDouble();

  test('credits the active bike once', () async {
    await seedTrip('d1');
    final credit = DetectedOdometerCredit();
    final km = await credit.creditDetection(userId: 'u1', detectionId: 'd1');
    expect(km, closeTo(2.95, 0.15)); // 59 gaps × ~50 m
    expect(await odometer('b1'), closeTo(1000 + km, 1e-6));
    expect(await odometer('b2'), 1000);
    expect(await MaintenanceForecastRepository.creditedKmFor('b1'),
        closeTo(km, 1e-6));

    // Re-running (a second foreground, a crash before markSummarized) adds
    // nothing.
    expect(await credit.creditDetection(userId: 'u1', detectionId: 'd1'), 0);
    expect(await odometer('b1'), closeTo(1000 + km, 1e-6));
  });

  test('riding inside a recorded ride is not counted twice (§90.C3)', () async {
    await seedTrip('d2');
    await db.insert('rides', {
      'id': 'r1',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': t0.subtract(const Duration(minutes: 1)).toIso8601String(),
      'end_time': t0.add(const Duration(hours: 1)).toIso8601String(),
      'status': 'completed',
      'created_at': t0.toIso8601String(),
    });
    final km = await DetectedOdometerCredit()
        .creditDetection(userId: 'u1', detectionId: 'd2');
    expect(km, 0);
    expect(await odometer('b1'), 1000);
  });

  test('too short to be a ride adds nothing', () async {
    await seedTrip('d3', fixes: 4); // ~150 m
    expect(
        await DetectedOdometerCredit()
            .creditDetection(userId: 'u1', detectionId: 'd3'),
        0);
  });
}
