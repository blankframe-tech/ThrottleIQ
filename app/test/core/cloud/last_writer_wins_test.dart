import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/cloud/last_writer_wins.dart';
import 'package:throttleiq/core/cloud/pull_watermark.dart';
import 'package:throttleiq/core/cloud/sync_manager.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Multi-device sync, last-writer-wins on `updated_at` (C4, critique B10).
void main() {
  const older = '2026-10-14T04:00:00.000Z';
  const newer = '2026-10-14T05:00:00.000Z';

  group('LastWriterWins.remoteIsNewer', () {
    test('a newer remote edit wins', () {
      expect(
          LastWriterWins.remoteIsNewer(
              {'updated_at': newer}, {'updated_at': older}),
          isTrue);
    });

    test('an older or equal remote never wins', () {
      expect(
          LastWriterWins.remoteIsNewer(
              {'updated_at': older}, {'updated_at': newer}),
          isFalse);
      expect(
          LastWriterWins.remoteIsNewer(
              {'updated_at': older}, {'updated_at': older}),
          isFalse);
    });

    test('a doc from an old build (no updated_at) counts as oldest', () {
      expect(LastWriterWins.remoteIsNewer({}, {'updated_at': older}), isFalse);
      expect(LastWriterWins.remoteIsNewer({}, {}), isFalse);
      expect(
          LastWriterWins.remoteIsNewer(null, {'updated_at': older}), isFalse);
    });

    test('a stamped remote beats an unstamped local row', () {
      expect(LastWriterWins.remoteIsNewer({'updated_at': older}, {}), isTrue);
    });

    test('compares instants, not strings', () {
      // 10:30 at +06:00 is 04:30 UTC: later than `older`, though the string
      // sorts before it would not tell you that.
      expect(
          LastWriterWins.remoteIsNewer(
              {'updated_at': '2026-10-14T10:30:00+06:00'},
              {'updated_at': older}),
          isTrue);
      // Sub-millisecond precision (Dart) against millisecond (SQLite).
      expect(
          LastWriterWins.remoteIsNewer(
              {'updated_at': '2026-10-14T04:00:00.000500Z'},
              {'updated_at': older}),
          isTrue);
    });
  });

  group('CloudRepository.downloadReplacesLocal', () {
    test('only over a synced local row', () {
      expect(
          CloudRepository.downloadReplacesLocal(
              {'updated_at': newer}, {'updated_at': older, 'synced': 1}),
          isTrue);
      expect(
          CloudRepository.downloadReplacesLocal(
              {'updated_at': newer}, {'updated_at': older, 'synced': 0}),
          isFalse,
          reason: 'unsynced local changes are left to the upload');
    });

    test('never with an older or unstamped remote', () {
      expect(
          CloudRepository.downloadReplacesLocal(
              {'updated_at': older}, {'updated_at': newer, 'synced': 1}),
          isFalse);
      expect(
          CloudRepository.downloadReplacesLocal(
              {'syncedAt': 'x'}, {'updated_at': older, 'synced': 1}),
          isFalse);
    });
  });

  group('remote doc → local row', () {
    final rideCols = {
      'id',
      'user_id',
      'bike_id',
      'start_time',
      'end_time',
      'created_at',
      'synced',
      'track_synced',
      'map_snapshot_path',
      'updated_at',
    };

    test('a ride from an old build: times to UTC, unknown fields dropped', () {
      final row = CloudRepository.rideRowFromCloud({
        'id': 'r',
        'start_time': '2026-10-14T07:30:00.000',
        'end_time': '2026-10-14T08:00:00.000',
        'created_at': '2026-10-14T07:30:00.000',
        'synced': 0,
        'syncedAt': 'server',
        'some_future_field': 1,
      }, rideCols);
      expect(row['start_time'],
          DateTime(2026, 10, 14, 7, 30).toUtc().toIso8601String());
      expect(
          row['end_time'], DateTime(2026, 10, 14, 8).toUtc().toIso8601String());
      expect(row['synced'], 1);
      expect(row.containsKey('syncedAt'), isFalse);
      expect(row.containsKey('some_future_field'), isFalse);
    });

    test('a ride overwrite keeps the trail flag and map snapshot local', () {
      final row = CloudRepository.rideOverwriteRow({
        'id': 'r',
        'bike_id': 'b2',
        'start_time': '2026-10-14T01:30:00.000Z',
        'track_synced': 0,
        'map_snapshot_path': '/other/phone/snap.png',
        'updated_at': newer,
      }, rideCols);
      expect(row['bike_id'], 'b2');
      expect(row['updated_at'], newer);
      expect(row.containsKey('track_synced'), isFalse);
      expect(row.containsKey('map_snapshot_path'), isFalse);
    });

    test('a bike overwrite keeps the active bike and the local photo', () {
      final cols = {'id', 'model', 'image_path', 'is_active', 'synced'};
      final failedPhoto = CloudRepository.bikeOverwriteRow(
          {'id': 'b', 'model': 'FZ v3', 'image_path': null, 'is_active': 1},
          cols);
      expect(failedPhoto, {'id': 'b', 'model': 'FZ v3', 'synced': 1});
      final url = CloudRepository.bikeOverwriteRow({
        'id': 'b',
        'image_path': 'https://res.cloudinary.com/x/image/upload/bikes/u/p.jpg',
      }, cols);
      expect(url['image_path'], startsWith('https://'));
    });

    test('a maintenance overwrite keeps a local receipt file', () {
      expect(
          CloudRepository.maintenanceOverwriteRow({
            'id': 'm',
            'cost': 900,
            'receipt_path': '/other/phone/receipt.jpg',
            'syncedAt': 'server',
          }),
          {'id': 'm', 'cost': 900});
      expect(
          CloudRepository.maintenanceOverwriteRow(
              {'id': 'm', 'receipt_path': 'https://example.com/r.jpg'}),
          {'id': 'm', 'receipt_path': 'https://example.com/r.jpg'});
    });
  });

  group('LastWriterWins.adopt (real SQLite)', () {
    late Database db;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      await db.insert('bikes', {
        'id': 'b1',
        'user_id': 'u',
        'brand': 'Yamaha',
        'model': 'FZ',
        'synced': 1,
        'created_at': older,
        'updated_at': older,
      });
    });
    tearDown(() => db.close());

    Future<Map<String, Object?>> bike() async =>
        (await db.query('bikes')).single;

    test('replaces a synced row and keeps the remote stamp', () async {
      final wrote = await LastWriterWins.adopt(
          db, 'bikes', {'id': 'b1', 'model': 'FZS', 'updated_at': newer},
          localUpdatedAt: older, onlyIfSynced: true);
      expect(wrote, isTrue);
      final b = await bike();
      expect(b['model'], 'FZS');
      expect(b['updated_at'], newer, reason: 'the trigger must not restamp');
      expect(b['synced'], 1);
    });

    test('never clobbers an edit made after the row was read', () async {
      // The rider edits while the download is in flight.
      await db.update('bikes', {'model': 'mine', 'synced': 0},
          where: 'id = ?', whereArgs: ['b1']);
      final wrote = await LastWriterWins.adopt(
          db, 'bikes', {'id': 'b1', 'model': 'theirs', 'updated_at': newer},
          localUpdatedAt: older);
      expect(wrote, isFalse);
      expect((await bike())['model'], 'mine');
    });

    test('onlyIfSynced leaves a row with unsynced changes alone', () async {
      // Inserted, not updated, so the trigger keeps the stamp as given.
      await db.insert('bikes', {
        'id': 'b2',
        'user_id': 'u',
        'brand': 'Bajaj',
        'model': 'Pulsar',
        'synced': 0,
        'created_at': older,
        'updated_at': older,
      });
      final wrote = await LastWriterWins.adopt(
          db, 'bikes', {'id': 'b2', 'model': 'theirs', 'updated_at': newer},
          localUpdatedAt: older, onlyIfSynced: true);
      expect(wrote, isFalse);
      expect(
          (await db.query('bikes', where: 'id = ?', whereArgs: ['b2']))
              .single['model'],
          'Pulsar');
      // Without the flag (the upload's adopt) the newer remote wins.
      expect(
          await LastWriterWins.adopt(
              db, 'bikes', {'id': 'b2', 'model': 'theirs', 'updated_at': newer},
              localUpdatedAt: older),
          isTrue);
    });
  });

  group('one full pull after upgrading to v28', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    final t = DateTime.utc(2026, 10, 14);

    test('clears every collection mark once, then never again', () async {
      for (final c in PullWatermark.collections) {
        await PullWatermark.write('alice', c, t);
      }
      await PullWatermark.write('bob', 'rides', t);
      await SyncManager.resetPullMarksOnceForV28('alice');
      for (final c in PullWatermark.collections) {
        expect(await PullWatermark.read('alice', c), isNull, reason: c);
      }
      expect(PullWatermark.collections, contains('fuelLogs'));
      expect(await PullWatermark.read('bob', 'rides'), t);

      await PullWatermark.write('alice', 'rides', t);
      await SyncManager.resetPullMarksOnceForV28('alice');
      expect(await PullWatermark.read('alice', 'rides'), t);
    });
  });
}
