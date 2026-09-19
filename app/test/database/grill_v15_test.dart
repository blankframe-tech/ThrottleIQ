@Timeout(Duration(seconds: 30))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/cloud/ride_track_loader.dart';
import 'package:throttleiq/core/cloud/sync_manager.dart';
import 'package:throttleiq/core/database/daos/auto_detection_dao.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/daos/ride_point_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/garage/data/models/bike_model.dart';

/// Schema v15 and the fixes that ride on it (claude_sol §1.2.2, §1.3.1,
/// §1.3.2, §1.4.2, §2.1.1), against a real in-memory SQLite.
void main() {
  sqfliteFfiInit();

  late Database db;
  final rideDao = RideDao();
  final bikeDao = BikeDao();
  final detectionDao = AutoDetectionDao();

  Future<void> openFresh() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
  }

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seedBike(String id,
      {String userId = 'alice',
      bool active = false,
      String createdAt = '2026-01-01T00:00:00.000'}) async {
    await db.insert('bikes', {
      'id': id,
      'user_id': userId,
      'brand': 'Yamaha',
      'model': 'FZ',
      'is_active': active ? 1 : 0,
      'created_at': createdAt,
    });
  }

  Future<void> seedRide(String id,
      {String userId = 'alice',
      String bikeId = 'bike-1',
      String status = 'completed',
      int synced = 0,
      int trackSynced = 0}) async {
    await db.insert('rides', {
      'id': id,
      'user_id': userId,
      'bike_id': bikeId,
      'start_time': DateTime(2026, 1, 1).toIso8601String(),
      'status': status,
      'synced': synced,
      'track_synced': trackSynced,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<Map<String, Object?>> rawRide(String id) async =>
      (await db.query('rides', where: 'id = ?', whereArgs: [id])).first;

  group('migration 14 -> 15', () {
    setUp(openFresh);

    test('adds the three columns and backfills synced rides to re-upload',
        () async {
      // Just the tables the v15 step touches, as they stood at v14.
      await db.execute('''
        CREATE TABLE bikes (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          brand TEXT NOT NULL, model TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 0,
          synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
      ''');
      await db.execute('''
        CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          bike_id TEXT NOT NULL, start_time TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
      ''');
      await db.execute('''
        CREATE TABLE auto_detections (id TEXT PRIMARY KEY,
          started_at TEXT NOT NULL, ended_at TEXT, trigger_source TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'recording', ride_id TEXT,
          discard_reason TEXT, created_at TEXT NOT NULL)
      ''');
      await db.insert('rides', {
        'id': 'old-synced',
        'user_id': 'alice',
        'bike_id': 'b',
        'start_time': '2026-01-01',
        'status': 'completed',
        'synced': 1,
        'created_at': '2026-01-01',
      });

      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 14, 15);
      // A re-run must be survivable, like every other step in the ladder.
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 14, 15);

      Future<List<String>> cols(String t) async =>
          (await db.rawQuery('PRAGMA table_info($t)'))
              .map((r) => r['name'] as String)
              .toList();
      expect(await cols('rides'), contains('track_synced'));
      expect(await cols('bikes'), contains('archived'));
      expect(await cols('auto_detections'), contains('user_id'));
      expect((await rawRide('old-synced'))['track_synced'], 0);
    });

    test('schemaVersion is 15', () {
      expect(DatabaseHelper.schemaVersion, 15);
    });
  });

  group('with the current schema', () {
    setUp(() async {
      await openFresh();
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await seedBike('bike-1', active: true);
    });

    group('crash rides (§69.O10)', () {
      test('getUnsynced includes crash rides, still excludes active ones',
          () async {
        await seedRide('done');
        await seedRide('crashed', status: 'crash');
        await seedRide('live', status: 'active');

        final ids = (await rideDao.getUnsynced('alice')).map((r) => r['id']);
        expect(ids, unorderedEquals(['done', 'crashed']));
      });

      test('history lists include crash rides', () async {
        await seedRide('done');
        await seedRide('crashed', status: 'crash');
        await seedRide('live', status: 'active');

        expect((await rideDao.getAllForUser('alice')).map((r) => r['id']),
            unorderedEquals(['done', 'crashed']));
        expect((await rideDao.getAllForBike('bike-1')).map((r) => r['id']),
            unorderedEquals(['done', 'crashed']));
      });
    });

    group('track sync (§1.3.2)', () {
      test('getTrackUnsynced wants synced rides whose trail is not up',
          () async {
        await seedRide('meta-only', synced: 1);
        await seedRide('both-up', synced: 1, trackSynced: 1);
        await seedRide('nothing-up');
        await seedRide('crash-meta-only', status: 'crash', synced: 1);
        await seedRide('bobs', userId: 'bob', synced: 1);

        final ids =
            (await rideDao.getTrackUnsynced('alice')).map((r) => r['id']);
        expect(ids, unorderedEquals(['meta-only', 'crash-meta-only']));
      });

      test('finalizeRide resets track_synced', () async {
        await seedRide('r', synced: 1, trackSynced: 1);
        await rideDao.finalizeRide('r', {'distance_m': 10.0});
        final row = await rawRide('r');
        expect(row['track_synced'], 0);
        expect(row['synced'], 0);
      });

      test('a trail that fails on one sync is retried and marked on the next',
          () async {
        await seedRide('r', synced: 1);
        var calls = 0;
        Future<void> flaky(String uid, String rideId) async {
          calls++;
          if (calls == 1) throw Exception('offline');
        }

        expect(await SyncManager.syncPendingTracks('alice', rideDao, flaky), 0);
        expect((await rawRide('r'))['track_synced'], 0);

        expect(await SyncManager.syncPendingTracks('alice', rideDao, flaky), 1);
        expect((await rawRide('r'))['track_synced'], 1);
        expect(calls, 2);

        // Nothing left to do on a third pass.
        expect(await SyncManager.syncPendingTracks('alice', rideDao, flaky), 0);
        expect(calls, 2);
      });

      test('track_synced never reaches the cloud payload', () {
        final payload = CloudRepository.ridePayload(
            {'id': 'r', 'track_synced': 0, 'synced': 0});
        expect(payload.containsKey('track_synced'), isFalse);
        expect(payload['id'], 'r');
      });
    });

    group('RideTrackLoader (§1.3.1)', () {
      Future<void> insertPoint(String rideId) => db.insert('ride_points', {
            'ride_id': rideId,
            'timestamp': DateTime(2026, 1, 1).toIso8601String(),
            'lat': 23.8,
            'lng': 90.4,
            'speed_ms': 5.0,
          });

      test('local points win and nothing is downloaded', () async {
        await seedRide('r');
        await insertPoint('r');
        var downloaded = false;
        final points = await RideTrackLoader.load('r',
            uid: 'alice',
            download: (_, __) async => downloaded = true);
        expect(points, hasLength(1));
        expect(downloaded, isFalse);
      });

      test('no local points: downloads, then rereads the local table',
          () async {
        await seedRide('r');
        final points = await RideTrackLoader.load('r',
            uid: 'alice', download: (uid, rideId) async {
          expect(uid, 'alice');
          await insertPoint(rideId);
          return true;
        });
        expect(points, hasLength(1));
        expect((await RidePointDao().getForRide('r')), hasLength(1));
      });

      test('a failed download yields an empty trail, not a throw', () async {
        await seedRide('r');
        final points = await RideTrackLoader.load('r',
            uid: 'alice', download: (_, __) async => throw Exception('503'));
        expect(points, isEmpty);
      });
    });

    group('auto-detection ownership (§1.4.2)', () {
      Future<void> seedDetection(String id,
          {String? userId,
          String status = AutoDetectionStatus.pending,
          DateTime? startedAt}) async {
        await db.insert('auto_detections', {
          'id': id,
          'started_at': (startedAt ?? DateTime.now()).toIso8601String(),
          'trigger_source': AutoTriggerSource.activityRecognition,
          'status': status,
          'created_at': DateTime.now().toIso8601String(),
          'user_id': userId,
        });
      }

      test("rider A's detection is not handed to rider B", () async {
        await seedDetection('a-trip', userId: 'alice');
        await seedDetection('b-trip', userId: 'bob');

        expect((await detectionDao.pendingDetections('bob')).map((r) => r['id']),
            ['b-trip']);
        expect(
            (await detectionDao.pendingDetections('alice')).map((r) => r['id']),
            ['a-trip']);
      });

      test('insertDetection stamps the owner', () async {
        await detectionDao.insertDetection(
          id: 'd',
          startedAt: DateTime.now(),
          triggerSource: AutoTriggerSource.manualTest,
          userId: 'alice',
        );
        final row = (await db.query('auto_detections')).single;
        expect(row['user_id'], 'alice');
      });

      test('unowned rows are claimed on a single-rider device', () async {
        await seedDetection('legacy');
        expect(await detectionDao.claimUnowned('alice'), 1);
        expect(
            (await detectionDao.pendingDetections('alice')).map((r) => r['id']),
            ['legacy']);
      });

      test('unowned rows are NOT claimed when another rider has data here',
          () async {
        await seedBike('bobs-bike', userId: 'bob');
        await seedDetection('legacy');
        expect(await detectionDao.claimUnowned('alice'), 0);
        expect(await detectionDao.pendingDetections('alice'), isEmpty);
        expect(await detectionDao.pendingDetections('bob'), isEmpty);
      });

      test('unowned rows older than 7 days are discarded as unowned_legacy',
          () async {
        final now = DateTime(2026, 9, 20);
        await seedDetection('stale',
            startedAt: now.subtract(const Duration(days: 8)));
        await seedDetection('fresh',
            startedAt: now.subtract(const Duration(days: 2)));
        await seedDetection('owned-old',
            userId: 'alice', startedAt: now.subtract(const Duration(days: 30)));
        await db.insert('auto_fixes', {
          'detection_id': 'stale',
          'timestamp': now.toIso8601String(),
          'lat': 0.0,
          'lng': 0.0,
          'speed_ms': 0.0,
        });

        expect(await detectionDao.discardStaleUnowned(now), 1);

        final stale = (await db.query('auto_detections',
                where: 'id = ?', whereArgs: ['stale']))
            .single;
        expect(stale['status'], AutoDetectionStatus.discarded);
        expect(stale['discard_reason'], AutoDetectionDao.unownedLegacyReason);
        expect(await detectionDao.fixesFor('stale'), isEmpty);
        final fresh = (await db.query('auto_detections',
                where: 'id = ?', whereArgs: ['fresh']))
            .single;
        expect(fresh['status'], AutoDetectionStatus.pending);
        expect(
            (await detectionDao.pendingDetections('alice')).map((r) => r['id']),
            ['owned-old']);
      });

      test('deleteUserData removes only that rider\'s detections', () async {
        await seedDetection('a-trip', userId: 'alice');
        await seedDetection('b-trip', userId: 'bob');
        await seedDetection('legacy');

        await DatabaseHelper.instance.deleteUserData('alice');

        final ids = (await db.query('auto_detections')).map((r) => r['id']);
        expect(ids, unorderedEquals(['b-trip', 'legacy']));
      });
    });

    group('bike archive (§2.1.1)', () {
      test('archiving hides the bike from the garage but keeps its rides',
          () async {
        await seedBike('bike-2', createdAt: '2026-02-01T00:00:00.000');
        await seedRide('r1');
        await seedRide('r2');

        await bikeDao.setArchived('bike-1', true);

        final garage =
            (await bikeDao.getAllForUser('alice')).map((r) => r['id']);
        expect(garage, ['bike-2']);
        expect(
            (await bikeDao.getAllForUser('alice', includeArchived: true))
                .map((r) => r['id']),
            unorderedEquals(['bike-1', 'bike-2']));
        expect((await bikeDao.getArchivedForUser('alice')).map((r) => r['id']),
            ['bike-1']);
        expect(await rideDao.getAllForUser('alice'), hasLength(2));
        expect(await rideDao.getAllForBike('bike-1'), hasLength(2));
      });

      test('archiving the active bike hands "active" to another bike',
          () async {
        await seedBike('bike-2', createdAt: '2026-02-01T00:00:00.000');
        await bikeDao.setArchived('bike-1', true);

        final b1 = await bikeDao.getById('bike-1');
        final b2 = await bikeDao.getById('bike-2');
        expect(b1!['is_active'], 0);
        expect(b1['archived'], 1);
        expect(b1['synced'], 0);
        expect(b2!['is_active'], 1);
      });

      test('unarchive brings it back', () async {
        await bikeDao.setArchived('bike-1', true);
        await bikeDao.setArchived('bike-1', false);
        expect((await bikeDao.getAllForUser('alice')).map((r) => r['id']),
            ['bike-1']);
      });

      test('BikeModel round-trips the flag; a doc without it reads unarchived',
          () async {
        await bikeDao.setArchived('bike-1', true);
        final entity = BikeModel.fromMap((await bikeDao.getById('bike-1'))!);
        expect(entity.isArchived, isTrue);
        expect(BikeModel.toMap(entity)['archived'], 1);

        final legacy = Map<String, dynamic>.from(
            (await bikeDao.getById('bike-1'))!)
          ..remove('archived');
        expect(BikeModel.fromMap(legacy).isArchived, isFalse);
      });

      test('hard delete still removes the bike and its rides', () async {
        await seedRide('r1');
        await bikeDao.delete('bike-1');
        expect(await bikeDao.getById('bike-1'), isNull);
        expect(await rideDao.getAllForUser('alice'), isEmpty);
      });
    });
  });

  group('CloudRepository helpers', () {
    setUp(openFresh);

    test('bikePayload sends archived only when set', () {
      expect(CloudRepository.bikePayload({'id': 'b', 'archived': 0}),
          isNot(contains('archived')));
      expect(CloudRepository.bikePayload({'id': 'b', 'archived': 1})['archived'],
          1);
    });

    test('remote deletes are chunked at 400, in order', () {
      final refs = List.generate(901, (i) => i);
      final chunks = CloudRepository.chunkForDelete(refs);
      expect(chunks.map((c) => c.length), [400, 400, 101]);
      expect(chunks.expand((c) => c), refs);
      expect(CloudRepository.chunkForDelete(<int>[]), isEmpty);
    });
  });
}
