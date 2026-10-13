@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/auto_detection_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Schema v19: `ride_points.segment_start` (§90.C6) and the `deleted_rides`
/// tombstone table (§90.C10), plus the DAO methods built on them.
void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<Set<String>> columns(String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((r) => r['name'] as String)
          .toSet();

  Future<Set<String>> tables() async => (await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
      .map((r) => r['name'] as String)
      .toSet();

  test('schemaVersion is 19 or later', () {
    expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(19));
  });

  test('v18 → v19 adds segment_start (default 0) and deleted_rides, keeps '
      'existing points', () async {
    await db.execute('''
      CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        bike_id TEXT NOT NULL, start_time TEXT NOT NULL)
    ''');
    await db.execute('''
      CREATE TABLE ride_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        speed_ms REAL NOT NULL,
        FOREIGN KEY(ride_id) REFERENCES rides(id)
      )
    ''');
    await db.insert('rides', {
      'id': 'r1',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': '2026-10-06T08:00:00Z',
    });
    await db.insert('ride_points', {
      'ride_id': 'r1',
      'timestamp': '2026-10-06T08:00:01Z',
      'lat': 23.8,
      'lng': 90.4,
      'speed_ms': 5.0,
    });

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 18, 19);
    // Re-running must be survivable.
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 18, 19);

    expect(await columns('ride_points'), contains('segment_start'));
    expect((await db.query('ride_points')).single['segment_start'], 0);
    expect(await tables(), contains('deleted_rides'));
    expect(await columns('deleted_rides'),
        containsAll(['id', 'user_id', 'deleted_at', 'synced']));
  });

  test('fresh schema and upgraded schema agree on the new columns', () async {
    await DatabaseHelper.instance.createSchemaForTesting(db);
    expect(await columns('ride_points'), contains('segment_start'));
    expect(await tables(), contains('deleted_rides'));
  });

  group('RideDao tombstones and windows', () {
    setUp(() async {
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u1',
        'brand': 'Bajaj',
        'model': 'Pulsar',
        'created_at': '2026-01-01T00:00:00Z',
      });
    });

    Future<void> insertRide(String id, String start, String? end,
        {String user = 'u1'}) =>
        db.insert('rides', {
          'id': id,
          'user_id': user,
          'bike_id': 'b1',
          'start_time': start,
          'end_time': end,
          'created_at': start,
        });

    test('deleteWithTombstone removes the ride and its points and records it',
        () async {
      await insertRide('r1', '2026-10-06T08:00:00Z', null);
      await db.insert('ride_points', {
        'ride_id': 'r1',
        'timestamp': '2026-10-06T08:00:01Z',
        'lat': 23.8,
        'lng': 90.4,
        'speed_ms': 5.0,
      });

      final dao = RideDao();
      await dao.deleteWithTombstone('r1', userId: 'u1');

      expect(await db.query('rides'), isEmpty);
      expect(await db.query('ride_points'), isEmpty);
      expect(await dao.deletedIds(), {'r1'});
      expect(await dao.pendingRemoteDeletions('u1'), ['r1']);
      expect(await dao.pendingRemoteDeletions('someone-else'), isEmpty);

      await dao.markDeletionSynced('r1');
      expect(await dao.pendingRemoteDeletions('u1'), isEmpty);
      // Kept, so a second device's copy can't come back.
      expect(await dao.deletedIds(), {'r1'});
    });

    test('account deletion removes that rider\'s tombstones only', () async {
      final dao = RideDao();
      await insertRide('r1', '2026-10-06T08:00:00Z', null);
      await dao.deleteWithTombstone('r1', userId: 'u1');
      await db.insert('deleted_rides', {
        'id': 'r2',
        'user_id': 'u2',
        'deleted_at': '2026-10-06T08:00:00Z',
      });

      await DatabaseHelper.instance.deleteUserData('u1');
      expect(await dao.deletedIds(), {'r2'});
    });

    test('rideWindows returns every ride of the rider, open-ended if active',
        () async {
      await insertRide('done', '2026-10-06T08:00:00Z', '2026-10-06T08:30:00Z');
      await insertRide('live', '2026-10-06T09:00:00.000', null);
      await insertRide('other', '2026-10-06T08:00:00Z', null, user: 'u2');

      final windows = await RideDao().rideWindows('u1');
      expect(windows.map((w) => w.id).toSet(), {'done', 'live'});
      final live = windows.firstWhere((w) => w.id == 'live');
      expect(live.end, isNull);
      final done = windows.firstWhere((w) => w.id == 'done');
      expect(done.end, DateTime.utc(2026, 10, 6, 8, 30));
    });
  });

  group('AutoDetectionDao gated close (§90.C2)', () {
    setUp(() async {
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
    });

    test('reports last activity and closes only the requested detection',
        () async {
      final dao = AutoDetectionDao();
      await dao.insertDetection(
        id: 'live',
        startedAt: DateTime.utc(2026, 10, 6, 8),
        triggerSource: AutoTriggerSource.activityRecognition,
        userId: 'u1',
      );
      await dao.insertDetection(
        id: 'dead',
        startedAt: DateTime.utc(2026, 10, 5, 8),
        triggerSource: AutoTriggerSource.activityRecognition,
        userId: 'u1',
      );
      await dao.appendFix(
        detectionId: 'live',
        timestamp: DateTime.utc(2026, 10, 6, 8, 20),
        lat: 23.8,
        lng: 90.4,
        speedMs: 9,
      );

      final rows = {
        for (final r in await dao.recordingDetectionsWithLastActivity())
          r.id: r.lastActivity,
      };
      expect(rows['live'], DateTime.utc(2026, 10, 6, 8, 20));
      expect(rows['dead'], DateTime.utc(2026, 10, 5, 8));

      await dao.closeRecordingDetection('dead');
      final statuses = {
        for (final r in await db.query('auto_detections'))
          r['id']: r['status'],
      };
      expect(statuses, {
        'live': AutoDetectionStatus.recording,
        'dead': AutoDetectionStatus.pending,
      });
    });
  });
}
