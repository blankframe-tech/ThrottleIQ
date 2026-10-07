@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/auto_detection_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/repositories/daily_ride_summary_repository.dart';

/// Schema v22 + issues §93.2: raw fixes of old summarized detections are
/// dropped, everything else is kept.
void main() {
  sqfliteFfiInit();

  late Database db;
  final now = DateTime(2026, 10, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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

  Future<void> seed(String id, DateTime start, String status) async {
    await db.insert('auto_detections', {
      'id': id,
      'started_at': start.toIso8601String(),
      'ended_at': start.add(const Duration(minutes: 5)).toIso8601String(),
      'trigger_source': 'test',
      'status': status,
      'user_id': 'u1',
      'created_at': start.toIso8601String(),
    });
    for (var i = 0; i < 3; i++) {
      await db.insert('auto_fixes', {
        'detection_id': id,
        'timestamp': start.add(Duration(minutes: i)).toIso8601String(),
        'lat': 23.0 + i * 0.001,
        'lng': 90.0,
        'speed_ms': 10.0,
      });
    }
  }

  Future<int> fixCount(String id) async {
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM auto_fixes WHERE detection_id = ?', [id]);
    return rows.single['c'] as int;
  }

  test('purges fixes of summarized detections older than 14 days', () async {
    await seed('old', now.subtract(const Duration(days: 20)), AutoDetectionStatus.summarized);

    final purged = await AutoDetectionDao().purgeOldSummarizedFixes(now);

    expect(purged, 1);
    expect(await fixCount('old'), 0);
    final row = (await db.query('auto_detections', where: 'id = ?', whereArgs: ['old'])).single;
    expect(row['fixes_purged'], 1);
  });

  test('keeps recent summarized detections and old ones in other statuses', () async {
    await seed('recent', now.subtract(const Duration(days: 3)), AutoDetectionStatus.summarized);
    await seed('old-pending', now.subtract(const Duration(days: 30)), AutoDetectionStatus.pending);

    final purged = await AutoDetectionDao().purgeOldSummarizedFixes(now);

    expect(purged, 0);
    expect(await fixCount('recent'), 3);
    expect(await fixCount('old-pending'), 3);
  });

  test('is idempotent: a second run purges nothing', () async {
    await seed('old', now.subtract(const Duration(days: 20)), AutoDetectionStatus.summarized);
    final dao = AutoDetectionDao();

    expect(await dao.purgeOldSummarizedFixes(now), 1);
    expect(await dao.purgeOldSummarizedFixes(now), 0);
  });

  test('purgeOldFixesIfDue runs once per day', () async {
    await seed('old', now.subtract(const Duration(days: 20)), AutoDetectionStatus.summarized);
    final repo = DailyRideSummaryRepository();

    expect(await repo.purgeOldFixesIfDue(now: now), 1);

    // New eligible detection the same day: throttled, nothing happens.
    await seed('old2', now.subtract(const Duration(days: 25)), AutoDetectionStatus.summarized);
    expect(await repo.purgeOldFixesIfDue(now: now.add(const Duration(hours: 3))), 0);
    expect(await fixCount('old2'), 3);

    // Next day it runs again.
    expect(await repo.purgeOldFixesIfDue(now: now.add(const Duration(days: 1))), 1);
    expect(await fixCount('old2'), 0);
  });

  test('the v21 → v22 upgrade adds fixes_purged and survives a re-run', () async {
    await db.execute('ALTER TABLE auto_detections DROP COLUMN fixes_purged');
    Future<bool> hasColumn() async => (await db.rawQuery('PRAGMA table_info(auto_detections)'))
        .any((c) => c['name'] == 'fixes_purged');
    expect(await hasColumn(), isFalse);

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 21, 22);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 21, 22);

    expect(await hasColumn(), isTrue);
  });
}
