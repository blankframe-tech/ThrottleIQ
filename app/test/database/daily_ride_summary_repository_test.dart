import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/repositories/daily_ride_summary_repository.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late DailyRideSummaryRepository repository;
  const userId = 'u1';

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    repository = DailyRideSummaryRepository();
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seedRide(String id, DateTime start, {int durationS = 600, double distanceM = 3000}) async {
    await db.insert('rides', {
      'id': id,
      'user_id': userId,
      'bike_id': 'b1',
      'start_time': start.toIso8601String(),
      'end_time': start.add(Duration(seconds: durationS)).toIso8601String(),
      'distance_m': distanceM,
      'moving_s': durationS,
      'duration_s': durationS,
      'max_speed_ms': 10.0,
      'status': 'completed',
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> seedDetection(String id, DateTime start, {
    String status = 'pending',
    int points = 5,
    double startLat = 23.0,
    double startLng = 90.0,
  }) async {
    await db.insert('auto_detections', {
      'id': id,
      'started_at': start.toIso8601String(),
      'ended_at': start.add(Duration(seconds: points * 60)).toIso8601String(),
      'trigger_source': 'test',
      'status': status,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'fixes_purged': 0,
    });
    for (var i = 0; i < points; i++) {
      await db.insert('auto_fixes', {
        'detection_id': id,
        'timestamp': start.add(Duration(seconds: i * 60)).toIso8601String(),
        'lat': startLat + i * 0.001,
        'lng': startLng + i * 0.001,
        'speed_ms': 10.0,
      });
    }
  }

  group('DailyRideSummaryRepository.summaryFor', () {
    test('returns empty summary for a day with no data', () async {
      final summary = await repository.summaryFor(userId, DateTime(2026, 1, 1));
      expect(summary.isEmpty, isTrue);
      expect(summary.rideCount, 0);
    });

    test('includes completed rides in the summary', () async {
      final day = DateTime(2026, 1, 1);
      await seedRide('r1', DateTime(2026, 1, 1, 8, 0));
      await seedRide('r2', DateTime(2026, 1, 1, 17, 0));

      final summary = await repository.summaryFor(userId, day);
      expect(summary.rideCount, 2);
      expect(summary.recordedRideCount, 2);
      expect(summary.distanceM, closeTo(6000, 0.1));
    });

    test('includes pending detections as segments', () async {
      final day = DateTime(2026, 1, 1);
      await seedDetection('d1', DateTime(2026, 1, 1, 8, 0)); // 5 mins

      final summary = await repository.summaryFor(userId, day);
      expect(summary.detectedSegmentCount, 1);
      // Wait, is 5 mins enough for a ride?
      // A 5 minute commute with speed=10 is 5*60*10 = 3000m, definitely a ride.
      expect(summary.rideCount, 1);
      expect(summary.detectedRideCount, 1);
    });

    test('includes summarized detections but ignores reconciled or discarded', () async {
      final day = DateTime(2026, 1, 1);
      await seedDetection('d1', DateTime(2026, 1, 1, 8, 0), status: 'summarized');
      await seedDetection('d2', DateTime(2026, 1, 1, 12, 0), status: 'reconciled');
      await seedDetection('d3', DateTime(2026, 1, 1, 16, 0), status: 'discarded');

      final summary = await repository.summaryFor(userId, day);
      expect(summary.detectedSegmentCount, 1);
      expect(summary.rideCount, 1);
    });

    test('ignores detections with purged fixes', () async {
      final day = DateTime(2026, 1, 1);
      await seedDetection('d1', DateTime(2026, 1, 1, 8, 0), status: 'summarized');
      // Purge fixes for d1 manually
      await db.update('auto_detections', {'fixes_purged': 1}, where: 'id = ?', whereArgs: ['d1']);
      await db.delete('auto_fixes', where: 'detection_id = ?', whereArgs: ['d1']);

      final summary = await repository.summaryFor(userId, day);
      expect(summary.isEmpty, isTrue);
      expect(summary.rideCount, 0);
    });

    test('combines rides and detections correctly', () async {
      final day = DateTime(2026, 1, 1);
      await seedRide('r1', DateTime(2026, 1, 1, 8, 0), durationS: 1200);
      await seedDetection('d1', DateTime(2026, 1, 1, 17, 0)); // Separate ride

      final summary = await repository.summaryFor(userId, day);
      expect(summary.rideCount, 2);
      expect(summary.recordedRideCount, 1);
      expect(summary.detectedRideCount, 1);
    });
  });
}
