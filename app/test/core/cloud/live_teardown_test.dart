@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// §90.C4: live-share teardown is per session, and only ever clears a
/// `livePointers/{uid}` that still points at that session.
void main() {
  sqfliteFfiInit();
  final queuedAt = DateTime.utc(2026, 10, 6, 10);

  group('shouldClearLivePointer', () {
    test('clears the pointer of the session being torn down', () {
      expect(
        shouldClearLivePointer(
          pointerExists: true,
          pointerToken: 'T1',
          pointerUpdatedAt: queuedAt.subtract(const Duration(hours: 1)),
          entryToken: 'T1',
          entryCreatedAt: queuedAt,
        ),
        isTrue,
      );
    });

    test('a stale teardown never clears a newer share\'s pointer', () {
      expect(
        shouldClearLivePointer(
          pointerExists: true,
          pointerToken: 'T2',
          pointerUpdatedAt: queuedAt.add(const Duration(minutes: 5)),
          entryToken: 'T1',
          entryCreatedAt: queuedAt,
        ),
        isFalse,
      );
    });

    test('a missing or already-cleared pointer is left alone', () {
      expect(
        shouldClearLivePointer(
          pointerExists: false,
          pointerToken: null,
          pointerUpdatedAt: null,
          entryToken: 'T1',
          entryCreatedAt: queuedAt,
        ),
        isFalse,
      );
      expect(
        shouldClearLivePointer(
          pointerExists: true,
          pointerToken: null,
          pointerUpdatedAt: null,
          entryToken: 'T1',
          entryCreatedAt: queuedAt,
        ),
        isFalse,
      );
    });

    test('a token-less teardown only clears a pointer older than itself', () {
      bool clears(DateTime pointerAt) => shouldClearLivePointer(
            pointerExists: true,
            pointerToken: 'T0',
            pointerUpdatedAt: pointerAt,
            entryToken: null,
            entryCreatedAt: queuedAt,
          );
      expect(clears(queuedAt.subtract(const Duration(hours: 2))), isTrue);
      expect(clears(queuedAt.add(const Duration(seconds: 1))), isFalse);
    });
  });

  group('enqueueLiveSessionTeardown', () {
    late Database db;

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

    test('two rides ended offline keep two teardowns, not one', () async {
      final dao = OutboxDao();
      final service = OutboxService(dao: dao, currentUid: () => 'u1');
      await service.enqueueLiveSessionTeardown(
          uid: 'u1', token: 'T1', attemptNow: false);
      await service.enqueueLiveSessionTeardown(
          uid: 'u1', token: 'T2', attemptNow: false);

      final ids = (await db.query('outbox', columns: ['id']))
          .map((r) => r['id'])
          .toSet();
      expect(ids, {
        liveTeardownEntryId('u1', 'T1'),
        liveTeardownEntryId('u1', 'T2'),
      });
      service.dispose();
    });
  });
}
