import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/impact_event_dao.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/core/services/crash_detection_settings.dart';
import 'package:throttleiq/features/ride/domain/entities/impact_event_types.dart';

/// Schema v29: `impact_events` (shadow-mode crash detection) and the two
/// ride columns, with ImpactEventDao against a real in-memory SQLite. Every
/// upgrade path into v29 is in schema_v29_merge_test.dart.
void main() {
  sqfliteFfiInit();

  group('v29 migration', () {
    late Database db;
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    });
    tearDown(() => db.close());

    test('schemaVersion is 29 or later', () {
      expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(29));
    });

    test('fresh schema has impact_events and the v29 ride columns', () async {
      await DatabaseHelper.instance.createSchemaForTesting(db);
      final cols = await db.rawQuery('PRAGMA table_info(impact_events)');
      expect(cols.map((c) => c['name']),
          containsAll(['id', 'ride_id', 'tier', 'imu', 'label', 'synced']));
      final rideCols = (await db.rawQuery('PRAGMA table_info(rides)'))
          .map((c) => c['name'])
          .toSet();
      expect(rideCols, containsAll(['phone_placement', 'imu_rate_hz']));
    });

    test('28 → 29 adds the table and columns, keeps rides, re-runnable',
        () async {
      await db.execute('''
        CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          bike_id TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT,
          status TEXT NOT NULL DEFAULT 'active', created_at TEXT NOT NULL,
          updated_at TEXT, synced INTEGER NOT NULL DEFAULT 0)
      ''');
      // The other v28 sync-stamp tables, which a v28 → v29 step re-checks.
      for (final t in ['bikes', 'maintenance_logs']) {
        await db.execute('CREATE TABLE $t (id TEXT PRIMARY KEY, '
            'created_at TEXT, last_ride_at TEXT, archived_at TEXT, '
            'updated_at TEXT, synced INTEGER NOT NULL DEFAULT 0)');
      }
      await db.insert('rides', {
        'id': 'old',
        'user_id': 'u',
        'bike_id': 'b',
        'start_time': '2026-01-01',
        'created_at': '2026-01-01',
      });
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 28, 29);
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 28, 29);

      final r = (await db.query('rides')).single;
      expect(r['phone_placement'], isNull);
      expect(r['imu_rate_hz'], isNull);
      expect(await db.query('impact_events'), isEmpty);
    });

    test('an upgrade that stops at 27 leaves v29 alone', () async {
      await db.execute('CREATE TABLE rides (id TEXT PRIMARY KEY)');
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 26, 27);
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'impact_events'");
      expect(tables, isEmpty);
    });
  });

  group('ImpactEventDao', () {
    late Database db;
    final dao = ImpactEventDao();

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      await db.insert('bikes', {
        'id': 'bike-1',
        'user_id': 'u1',
        'brand': 'Honda',
        'model': 'CG 125',
        'cc': 125,
        'created_at': '2026-10-01',
      });
      for (final id in ['ride-1', 'ride-2']) {
        await db.insert('rides', {
          'id': id,
          'user_id': 'u1',
          'bike_id': 'bike-1',
          'start_time': '2026-10-14T14:04:16Z',
          'created_at': '2026-10-14T14:04:16Z',
        });
      }
    });

    tearDown(() async {
      DatabaseHelper.overrideDatabaseForTesting(null);
      await db.close();
    });

    Map<String, Object?> event(String id,
            {String rideId = 'ride-1', int tier = 1, String at = 'T1'}) =>
        {
          'id': id,
          'ride_id': rideId,
          'user_id': 'u1',
          'at': '2026-10-14T15:28:58.900Z$at',
          'tier': tier,
          'reason': 'tipOver',
          'speed_before_ms': 0.0,
          'imu': Uint8List.fromList([1, 2, 3]),
          'created_at': '2026-10-14T15:29:30Z',
        };

    test('pending questions are unanswered tier 1+ on that ride, oldest first',
        () async {
      await dao.insert(event('b', at: 'b'));
      await dao.insert(event('a', at: 'a'));
      await dao.insert(event('z', tier: 0));
      await dao.insert(event('other', rideId: 'ride-2'));
      final pending = await dao.pendingQuestions('ride-1');
      expect(pending.map((r) => r['id']), ['a', 'b']);
    });

    test('an answer removes the question and queues the row for sync',
        () async {
      await dao.insert(event('a'));
      await dao.setLabel('a',
          label: ImpactLabel.crash,
          consent: true,
          detail: {'severity': 'minor', 'surface': 'rail_crossing'},
          now: DateTime.utc(2026, 10, 14, 16));
      expect(await dao.pendingQuestions('ride-1'), isEmpty);
      final row = (await dao.getForRide('ride-1')).single;
      expect(row['label'], 'crash');
      expect(row['consent_research'], 1);
      expect(row['synced'], 0);
      expect(jsonDecode(row['label_detail']! as String),
          {'severity': 'minor', 'surface': 'rail_crossing'});
    });

    test('unsynced rows come with their bike for the research copy', () async {
      await dao.insert(event('a'));
      final rows = await dao.unsyncedForUser('u1');
      expect(rows.single['bike_cc'], 125);
      expect(rows.single['bike_model'], 'CG 125');
      expect(await dao.unsyncedForUser('someone-else'), isEmpty);
    });

    test('markSynced skips a row relabelled since it was read', () async {
      await dao.insert(event('a'));
      final read = (await dao.unsyncedForUser('u1')).single;
      await dao.setLabel('a', label: ImpactLabel.bump, consent: false);
      await dao.markSynced('a', labeledAt: read['labeled_at'] as String?);
      expect((await dao.unsyncedForUser('u1')).single['label'], 'bump',
          reason: 'the new answer still needs uploading');

      final fresh = (await dao.unsyncedForUser('u1')).single;
      await dao.markSynced('a', labeledAt: fresh['labeled_at'] as String?);
      expect(await dao.unsyncedForUser('u1'), isEmpty);
    });

    test('a reported miss is tier -1, already answered', () async {
      await dao.reportMissed(
        id: 'm',
        rideId: 'ride-1',
        userId: 'u1',
        at: DateTime.utc(2026, 10, 14, 15, 28, 50),
        consent: false,
        placement: PhonePlacement.pocket,
        detail: {'surface': 'rail_crossing'},
      );
      final row = (await dao.getForRide('ride-1')).single;
      expect(row['tier'], -1);
      expect(row['label'], 'missed');
      expect(row['placement_declared'], 'pocket');
      expect(await dao.pendingQuestions('ride-1'), isEmpty);
    });

    test('changing consent re-queues answered rows only', () async {
      await dao.insert(event('answered'));
      await dao.insert(event('open', at: 'x'));
      await dao.setLabel('answered', label: ImpactLabel.fall, consent: false);
      for (final r in await dao.unsyncedForUser('u1')) {
        await dao.markSynced(r['id']! as String,
            labeledAt: r['labeled_at'] as String?);
      }
      expect(await dao.setConsentForUser('u1', true), 1);
      final rows = await dao.unsyncedForUser('u1');
      expect(rows.single['id'], 'answered');
      expect(rows.single['consent_research'], 1);
      expect(await dao.setConsentForUser('u1', true), 0, reason: 'no-op');
    });

    test('CrashResearchConsent defaults off and applies to stored answers',
        () async {
      SharedPreferences.setMockInitialValues({});
      expect(await CrashResearchConsent.isEnabled(), isFalse);
      await dao.insert(event('a'));
      await dao.setLabel('a', label: ImpactLabel.crash, consent: false);
      await CrashResearchConsent.setEnabled(true, uid: 'u1');
      expect(await CrashResearchConsent.isEnabled(), isTrue);
      expect((await dao.getForRide('ride-1')).single['consent_research'], 1);
    });

    test('PhonePlacementSetting remembers the last answer', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await PhonePlacementSetting.current(), PhonePlacement.unknown);
      await PhonePlacementSetting.set(PhonePlacement.mount);
      expect(await PhonePlacementSetting.current(), PhonePlacement.mount);
    });

    group('rows go with their ride', () {
      Future<int> count() async => (await db.query('impact_events')).length;

      test('RideDao.delete', () async {
        await dao.insert(event('a'));
        await dao.insert(event('b', rideId: 'ride-2'));
        await RideDao().delete('ride-1');
        expect(await count(), 1);
      });

      test('RideDao.deleteWithTombstone', () async {
        await dao.insert(event('a'));
        await RideDao().deleteWithTombstone('ride-1', userId: 'u1');
        expect(await count(), 0);
      });

      test('RideDao.deleteForBike and deleteAllForUser', () async {
        await dao.insert(event('a'));
        await dao.insert(event('b', rideId: 'ride-2'));
        await RideDao().deleteForBike('bike-1');
        expect(await count(), 0);
        await dao.insert(event('c'));
        await RideDao().deleteAllForUser('u1');
        expect(await count(), 0);
      });

      test('BikeDao.delete (deleting or purging a bike)', () async {
        await dao.insert(event('a'));
        await dao.insert(event('b', rideId: 'ride-2'));
        await BikeDao().delete('bike-1');
        expect(await count(), 0);
      });

      test('DatabaseHelper.deleteUserData', () async {
        await dao.insert(event('a'));
        await dao.insert({...event('orphan'), 'ride_id': 'gone'});
        await DatabaseHelper.instance.deleteUserData('u1');
        expect(await count(), 0);
      });
    });
  });

  group('ride payload (schema v28)', () {
    test('placement and IMU rate go up only when set', () {
      final base = {'id': 'r', 'synced': 0, 'track_synced': 0};
      final none = CloudRepository.ridePayload(
          {...base, 'phone_placement': null, 'imu_rate_hz': null});
      expect(none.containsKey('phone_placement'), isFalse);
      expect(none.containsKey('imu_rate_hz'), isFalse);
      final set = CloudRepository.ridePayload(
          {...base, 'phone_placement': 'pocket', 'imu_rate_hz': 49.8});
      expect(set['phone_placement'], 'pocket');
      expect(set['imu_rate_hz'], 49.8);
    });
  });
}
