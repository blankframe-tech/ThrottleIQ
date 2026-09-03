@Timeout(Duration(seconds: 30))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Covers the offline write queue behind "end a ride / share a ride with no
/// connection" (docs/Issues.md §25).
///
/// The DAO half runs against a REAL in-memory SQLite, same reasoning as
/// `bike_dao_delete_test.dart`: the queue's whole job is to still be there
/// after the process dies, and that is a property of the storage, not of a
/// mock. The delivery half is not covered here — it needs a live Firestore
/// and is what the emulator/manual pass is for; what IS covered is that an
/// undelivered intent survives, comes back in order, and backs off.
void main() {
  sqfliteFfiInit();

  group('outboxBackoff', () {
    test('starts at 30s and doubles', () {
      expect(outboxBackoff(0), const Duration(seconds: 30));
      expect(outboxBackoff(1), const Duration(minutes: 1));
      expect(outboxBackoff(2), const Duration(minutes: 2));
      expect(outboxBackoff(3), const Duration(minutes: 4));
    });

    test('caps at 30 minutes rather than growing without bound', () {
      expect(outboxBackoff(10), const Duration(minutes: 30));
      expect(outboxBackoff(50), const Duration(minutes: 30));
      // The guard that matters: a large attempt count must not overflow the
      // shift into a negative or absurd duration.
      expect(outboxBackoff(1000), const Duration(minutes: 30));
    });

    test('never returns a negative or zero delay', () {
      for (var i = 0; i < 100; i++) {
        expect(outboxBackoff(i).inSeconds, greaterThan(0));
      }
    });
  });

  group('OutboxDao', () {
    late Database db;
    late OutboxDao dao;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.overrideDatabaseForTesting(db);
      dao = OutboxDao();
    });

    tearDown(() async {
      DatabaseHelper.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('a queued intent survives and round-trips its payload', () async {
      await dao.enqueue(
        id: 'share:ride-1',
        kind: OutboxKind.shareRide,
        payload: {
          'rideId': 'ride-1',
          'distanceKm': 12.5,
          'polyline': [
            [23.8, 90.4],
            [23.9, 90.5],
          ],
        },
      );

      final entries = await dao.all();
      expect(entries, hasLength(1));
      expect(entries.single.kind, OutboxKind.shareRide);
      expect(entries.single.payload['rideId'], 'ride-1');
      expect(entries.single.payload['distanceKm'], 12.5);
      expect((entries.single.payload['polyline'] as List).first, [23.8, 90.4]);
      expect(entries.single.attempts, 0);
    });

    test('re-queuing the same id supersedes rather than duplicating', () async {
      // Sharing the same ride twice while offline must not post it twice.
      await dao.enqueue(
        id: 'share:ride-1',
        kind: OutboxKind.shareRide,
        payload: {'caption': 'first'},
      );
      await dao.enqueue(
        id: 'share:ride-1',
        kind: OutboxKind.shareRide,
        payload: {'caption': 'second'},
      );

      final entries = await dao.all();
      expect(entries, hasLength(1));
      expect(entries.single.payload['caption'], 'second');
    });

    test('due() hides an entry until its backoff has elapsed', () async {
      await dao.enqueue(id: 'a', kind: OutboxKind.shareRide, payload: {});
      expect(await dao.due(), hasLength(1));

      await dao.recordFailure(
        id: 'a',
        error: 'offline',
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(await dao.due(), isEmpty);
      // ...and reappears once that moment passes.
      expect(
        await dao.due(now: DateTime.now().add(const Duration(minutes: 6))),
        hasLength(1),
      );
    });

    test('recordFailure increments attempts and keeps the entry', () async {
      await dao.enqueue(id: 'a', kind: OutboxKind.shareRide, payload: {});
      for (var i = 0; i < 3; i++) {
        await dao.recordFailure(
          id: 'a',
          error: 'still offline',
          nextAttemptAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      final entry = (await dao.all()).single;
      expect(entry.attempts, 3);
      expect(entry.lastError, 'still offline');
      // Crucially still deliverable — a failed attempt must never drop the
      // rider's intent.
      expect(await dao.due(), hasLength(1));
    });

    test('a long error message is truncated rather than stored whole', () async {
      await dao.enqueue(id: 'a', kind: OutboxKind.shareRide, payload: {});
      await dao.recordFailure(
        id: 'a',
        error: 'x' * 5000,
        nextAttemptAt: DateTime.now(),
      );
      expect((await dao.all()).single.lastError!.length, 500);
    });

    test('due() returns oldest intent first', () async {
      // Ordering is load-bearing: ending a ride is queued before the share
      // that refers to it.
      await dao.enqueue(id: 'first', kind: OutboxKind.liveSessionTeardown, payload: {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await dao.enqueue(id: 'second', kind: OutboxKind.shareRide, payload: {});

      final due = await dao.due();
      expect(due.map((e) => e.id), ['first', 'second']);
    });

    test('updatePayload rewrites in place, for resuming a partial upload',
        () async {
      await dao.enqueue(
        id: 'share:ride-1',
        kind: OutboxKind.shareRide,
        payload: {'localPhotoPaths': ['/a.jpg', '/b.jpg'], 'uploadedPhotoUrls': []},
      );

      final entry = (await dao.all()).single;
      await dao.updatePayload(
        id: entry.id,
        payload: {...entry.payload, 'uploadedPhotoUrls': ['https://x/a.jpg']},
      );

      final updated = (await dao.all()).single;
      expect(updated.payload['uploadedPhotoUrls'], ['https://x/a.jpg']);
      // Untouched fields must survive the rewrite, or a retry re-uploads.
      expect(updated.payload['localPhotoPaths'], ['/a.jpg', '/b.jpg']);
    });

    test('a corrupt payload decodes to empty instead of throwing', () async {
      // Written by hand: a row like this can only come from a bad migration or
      // a truncated write, and it must not be able to crash the drain loop for
      // every other queued entry.
      await db.insert('outbox', {
        'id': 'bad',
        'kind': OutboxKind.shareRide,
        'payload': '{not json',
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 0,
      });

      final entry = (await dao.all()).single;
      expect(entry.payload, isEmpty);
    });

    test('pendingCount and pendingCountOfKind report queue depth', () async {
      await dao.enqueue(id: 'a', kind: OutboxKind.shareRide, payload: {});
      await dao.enqueue(id: 'b', kind: OutboxKind.shareRide, payload: {});
      await dao.enqueue(id: 'c', kind: OutboxKind.liveSessionTeardown, payload: {});

      expect(await dao.pendingCount(), 3);
      expect(await dao.pendingCountOfKind(OutboxKind.shareRide), 2);

      await dao.delete('a');
      expect(await dao.pendingCount(), 2);
    });
  });

  group('OutboxService.decodePolylinePayload', () {
    test('decodes flat array format', () {
      final flat = [23.8, 90.4, 23.9, 90.5];
      final result = OutboxService.decodePolylinePayload(flat);
      expect(result, hasLength(2));
      expect(result[0].latitude, 23.8);
      expect(result[0].longitude, 90.4);
      expect(result[1].latitude, 23.9);
      expect(result[1].longitude, 90.5);
    });

    test('decodes legacy nested array format', () {
      final nested = [
        [23.8, 90.4],
        [23.9, 90.5],
      ];
      final result = OutboxService.decodePolylinePayload(nested);
      expect(result, hasLength(2));
      expect(result[0].latitude, 23.8);
      expect(result[0].longitude, 90.4);
      expect(result[1].latitude, 23.9);
      expect(result[1].longitude, 90.5);
    });

    test('handles empty or non-list payloads gracefully', () {
      expect(OutboxService.decodePolylinePayload(null), isEmpty);
      expect(OutboxService.decodePolylinePayload([]), isEmpty);
      expect(OutboxService.decodePolylinePayload('not a list'), isEmpty);
    });
  });
}
