@Timeout(Duration(seconds: 30))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/garage/data/bike_archive_service.dart';
import 'package:throttleiq/features/garage/data/models/bike_model.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';

/// Archive-with-cleanup, the three-month purge and the v24 migration, against
/// a real in-memory SQLite.
void main() {
  sqfliteFfiInit();

  late Database db;
  final dao = BikeDao();

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seedBike(String id, {bool active = false}) => db.insert('bikes', {
        'id': id,
        'user_id': 'alice',
        'brand': 'Yamaha',
        'model': 'FZ',
        'image_path': '/photos/$id.jpg',
        'is_active': active ? 1 : 0,
        'total_distance_m': 12000.0,
        'ride_count': 3,
        'created_at': '2026-01-01T00:00:00.000',
      });

  Future<void> seedLog(String id, String bikeId) => db.insert('maintenance_logs', {
        'id': id,
        'bike_id': bikeId,
        'service_type': 'oil',
        'date': '2026-02-01',
        'odometer_km': 1000.0,
        'receipt_path': '/receipts/$id.jpg',
        'created_at': '2026-02-01',
      });

  Future<Map<String, Object?>> bike(String id) async =>
      (await db.query('bikes', where: 'id = ?', whereArgs: [id])).first;

  test('plain archive keeps everything and starts the clock', () async {
    await seedBike('b1');
    await seedLog('l1', 'b1');

    await dao.setArchived('b1', true);

    final row = await bike('b1');
    expect(row['archived'], 1);
    expect(DateTime.tryParse(row['archived_at'] as String), isNotNull);
    expect(row['image_path'], '/photos/b1.jpg');
    expect(row['total_distance_m'], 12000.0);
    expect(row['ride_count'], 3);
    expect(await db.query('maintenance_logs'), hasLength(1));
  });

  test('unarchive clears the clock', () async {
    await seedBike('b1');
    await dao.setArchived('b1', true);
    await dao.setArchived('b1', false);
    final row = await bike('b1');
    expect(row['archived'], 0);
    expect(row['archived_at'], isNull);
  });

  test('cleanup options remove only what was asked for', () async {
    await seedBike('b1');
    await seedLog('l1', 'b1');

    await dao.setArchived('b1', true, resetMiles: true, deletePhotos: true);

    final row = await bike('b1');
    expect(row['total_distance_m'], 0);
    expect(row['ride_count'], 0);
    expect(row['image_path'], isNull);
    // Logs are kept, but their receipt photos are gone.
    final logs = await db.query('maintenance_logs');
    expect(logs, hasLength(1));
    expect(logs.first['receipt_path'], isNull);
  });

  test('deleting service logs leaves tombstones for the cloud', () async {
    await seedBike('b1');
    await seedLog('l1', 'b1');
    await seedLog('l2', 'b1');
    await seedLog('other', 'b2');

    await dao.setArchived('b1', true, deleteServiceLogs: true);

    final left = await db.query('maintenance_logs');
    expect(left.map((r) => r['id']), ['other']);
    final tombstones = await db.query('deleted_maintenance_logs');
    expect(tombstones.map((r) => r['id']).toSet(), {'l1', 'l2'});
    expect(tombstones.every((r) => r['synced'] == 0), isTrue);
  });

  test('archiving the active bike hands active to another', () async {
    await seedBike('b1', active: true);
    await seedBike('b2');
    await dao.setArchived('b1', true);
    expect((await bike('b2'))['is_active'], 1);
  });

  group('purgeExpired', () {
    test('deletes only bikes archived longer than the retention', () async {
      await seedBike('old');
      await seedBike('recent');
      await seedBike('live');
      await dao.setArchived('old', true);
      await dao.setArchived('recent', true);
      final now = DateTime(2026, 10, 8);
      await db.update(
          'bikes',
          {
            'archived_at':
                now.subtract(kArchiveRetention + const Duration(days: 1)).toIso8601String()
          },
          where: 'id = ?',
          whereArgs: ['old']);
      await db.update(
          'bikes',
          {
            'archived_at':
                now.subtract(kArchiveRetention - const Duration(days: 1)).toIso8601String()
          },
          where: 'id = ?',
          whereArgs: ['recent']);

      final removed = <String>[];
      final service = BikeArchiveService(
        deleteSharedRides: (uid, bikeId) async {
          removed.add(bikeId);
          return 0;
        },
      );
      final purged = await service.purgeExpired('alice', now: now);

      expect(purged, 1);
      expect(removed, ['old']);
      final ids = (await db.query('bikes')).map((r) => r['id']).toSet();
      expect(ids, {'recent', 'live'});
      // Tombstoned so the cloud copy goes too and a sync can't bring it back.
      expect((await db.query('deleted_bikes')).map((r) => r['id']), ['old']);
    });

    test('a failing shared-ride delete does not block the purge', () async {
      await seedBike('old');
      await dao.setArchived('old', true);
      await db.update('bikes', {'archived_at': '2020-01-01T00:00:00.000'});
      final service = BikeArchiveService(
        deleteSharedRides: (uid, bikeId) async => throw StateError('offline'),
      );
      expect(await service.purgeExpired('alice'), 1);
      expect(await db.query('bikes'), isEmpty);
    });
  });

  test('archive aborts before touching the bike if shared rides fail', () async {
    await seedBike('b1');
    final service = BikeArchiveService(
      deleteSharedRides: (uid, bikeId) async => throw StateError('offline'),
    );
    final entity = BikeModel.fromMap(await bike('b1'));
    await expectLater(
        service.archive(entity, const ArchiveCleanup(sharedRides: true)),
        throwsStateError);
    expect((await bike('b1'))['archived'], 0);
  });

  group('v24 migration', () {
    test('adds archived_at and starts the clock for already-archived bikes',
        () async {
      // Rewind the bikes table to its v23 shape on the schema from setUp.
      final old = db;
      await old.execute('DROP TABLE bikes');
      await old.execute('''
        CREATE TABLE bikes (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          brand TEXT NOT NULL, model TEXT NOT NULL,
          archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
      ''');
      await old.insert('bikes', {
        'id': 'a', 'user_id': 'u', 'brand': 'x', 'model': 'y',
        'archived': 1, 'created_at': '2026-01-01'
      });
      await old.insert('bikes', {
        'id': 'b', 'user_id': 'u', 'brand': 'x', 'model': 'y',
        'archived': 0, 'created_at': '2026-01-01'
      });

      await DatabaseHelper.instance.upgradeSchemaForTesting(old, 23, 24);
      await DatabaseHelper.instance.upgradeSchemaForTesting(old, 23, 24);

      final rows = {
        for (final r in await old.query('bikes')) r['id']: r['archived_at']
      };
      expect(rows['a'], isNotNull);
      expect(rows['b'], isNull);
    });
  });

  group('entity and payload', () {
    test('daysUntilPurge counts down and floors at zero', () {
      final archivedAt = DateTime(2026, 7, 10);
      final b = BikeModel.fromMap({
        'id': 'b', 'user_id': 'u', 'brand': 'x', 'model': 'y',
        'is_active': 0, 'total_distance_m': 0, 'ride_count': 0,
        'archived': 1, 'archived_at': archivedAt.toIso8601String(),
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(b.daysUntilPurge(archivedAt), kArchiveRetention.inDays);
      expect(b.daysUntilPurge(archivedAt.add(const Duration(days: 100))), 0);
    });

    test('bikePayload only sends archived_at for an archived bike', () {
      expect(
          CloudRepository.bikePayload(
              {'id': 'b', 'archived': 0, 'archived_at': '2026-01-01'}),
          isNot(contains('archived_at')));
      expect(
          CloudRepository.bikePayload(
              {'id': 'b', 'archived': 1, 'archived_at': '2026-01-01'}),
          contains('archived_at'));
    });
  });
}
