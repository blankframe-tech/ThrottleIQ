@Timeout(Duration(seconds: 30))
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// §69.O4: the outbox used to retry a rejected write every 30 minutes
/// forever, and replayed every queued entry under whoever happened to be
/// signed in. These pin down the dead-letter policy and the account scoping.
///
/// Delivery is replaced via `deliverOverride`, so the policy in `_deliver`
/// runs for real against a real in-memory SQLite without needing Firestore.
void main() {
  sqfliteFfiInit();

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

  /// Makes every queued entry due again, standing in for the backoff
  /// elapsing between drains.
  Future<void> makeAllDue() =>
      db.update('outbox', {'next_attempt_at': null});

  FirebaseException rejected(String code) =>
      FirebaseException(plugin: 'cloud_firestore', code: code);

  test('a permission-denied entry dies after 3 attempts', () async {
    var calls = 0;
    final service = OutboxService(
      dao: dao,
      currentUid: () => 'alice',
      deliverOverride: (_) async {
        calls++;
        throw rejected('permission-denied');
      },
    );
    await dao.enqueue(
      id: 'share:r1',
      kind: OutboxKind.shareRide,
      payload: {'rideId': 'r1', 'userId': 'alice'},
    );

    for (var i = 0; i < 2; i++) {
      await service.drain();
      await makeAllDue();
    }
    var entry = (await dao.all()).single;
    expect(entry.isDead, isFalse);
    expect(entry.permanentFailures, 2);
    expect(await service.pendingCount(), 1);

    await service.drain();
    entry = (await dao.all()).single;
    expect(entry.isDead, isTrue);
    expect(entry.attempts, 3);
    expect(entry.lastError, contains('permission-denied'));

    // Dead: no longer due, no longer "pending", listed for the rider.
    await makeAllDue();
    await service.drain();
    expect(calls, 3);
    expect(await service.pendingCount(), 0);
    expect(await service.pendingShareCount(), 0);
    expect((await service.deadEntries()).map((e) => e.id), ['share:r1']);
  });

  test('transient errors retire an entry only after 20 attempts', () async {
    final service = OutboxService(
      dao: dao,
      currentUid: () => 'alice',
      deliverOverride: (_) async => throw rejected('unavailable'),
    );
    await dao.enqueue(
      id: 'm:1',
      kind: OutboxKind.maintenanceLog,
      payload: {'uid': 'alice'},
    );

    for (var i = 0; i < 19; i++) {
      await service.drain();
      await makeAllDue();
    }
    expect((await dao.all()).single.isDead, isFalse);
    expect((await dao.all()).single.permanentFailures, 0);

    await service.drain();
    final entry = (await dao.all()).single;
    expect(entry.attempts, kOutboxMaxAttempts);
    expect(entry.isDead, isTrue);
  });

  test('a deferred (offline/timeout) result also counts toward the cap',
      () async {
    final service = OutboxService(
      dao: dao,
      currentUid: () => 'alice',
      deliverOverride: (_) async => OutboxDeliveryResult.deferred,
    );
    await dao.enqueue(
      id: 'm:1',
      kind: OutboxKind.maintenanceLog,
      payload: {'uid': 'alice'},
    );
    for (var i = 0; i < kOutboxMaxAttempts; i++) {
      await service.drain();
      await makeAllDue();
    }
    expect((await dao.all()).single.isDead, isTrue);
  });

  test("user A's entry is not attempted while B is signed in", () async {
    final attempted = <String>[];
    var signedIn = 'bob';
    final service = OutboxService(
      dao: dao,
      currentUid: () => signedIn,
      deliverOverride: (e) async {
        attempted.add(e.id);
        return OutboxDeliveryResult.delivered;
      },
    );
    await dao.enqueue(
      id: 'share:alice-ride',
      kind: OutboxKind.shareRide,
      payload: {'rideId': 'r1', 'userId': 'alice'},
    );
    await dao.enqueue(
      id: 'live-teardown:bob',
      kind: OutboxKind.liveSessionTeardown,
      payload: {'uid': 'bob', 'token': null},
    );

    await service.drain();
    expect(attempted, ['live-teardown:bob']);
    // Alice's row is untouched — no attempt counted, no backoff, no error.
    final alice = (await dao.all()).single;
    expect(alice.id, 'share:alice-ride');
    expect(alice.attempts, 0);
    expect(alice.nextAttemptAt, isNull);
    expect(alice.lastError, isNull);

    // ...and goes out once Alice is back.
    signedIn = 'alice';
    await service.drain();
    expect(attempted, ['live-teardown:bob', 'share:alice-ride']);
    expect(await dao.all(), isEmpty);
  });

  test('nothing owned is attempted while signed out', () async {
    var calls = 0;
    final service = OutboxService(
      dao: dao,
      currentUid: () => null,
      deliverOverride: (_) async {
        calls++;
        return OutboxDeliveryResult.delivered;
      },
    );
    await dao.enqueue(
      id: 'm:1',
      kind: OutboxKind.maintenanceLog,
      payload: {'uid': 'alice'},
    );
    await service.drain();
    expect(calls, 0);
    expect((await dao.all()).single.attempts, 0);
  });

  test('retryDead revives with clean counters and attempts once', () async {
    var fail = true;
    final service = OutboxService(
      dao: dao,
      currentUid: () => 'alice',
      deliverOverride: (_) async {
        if (fail) throw rejected('permission-denied');
        return OutboxDeliveryResult.delivered;
      },
    );
    await dao.enqueue(
      id: 'share:r1',
      kind: OutboxKind.shareRide,
      payload: {'userId': 'alice'},
    );
    for (var i = 0; i < kOutboxMaxPermanentFailures; i++) {
      await service.drain();
      await makeAllDue();
    }
    expect(await service.deadCount(), 1);

    // Still rejected: a retry is one fresh attempt, not an instant re-death.
    expect(await service.retryDead('share:r1'), isFalse);
    var entry = (await dao.all()).single;
    expect(entry.isDead, isFalse);
    expect(entry.attempts, 1);
    expect(entry.permanentFailures, 1);

    fail = false;
    await dao.revive('share:r1');
    expect(await service.retryDead('share:r1'), isTrue);
    expect(await dao.all(), isEmpty);
  });

  test('discard removes a dead entry for good', () async {
    final service = OutboxService(
      dao: dao,
      currentUid: () => 'alice',
      deliverOverride: (_) async => throw rejected('invalid-argument'),
    );
    await dao.enqueue(
      id: 'm:1',
      kind: OutboxKind.maintenanceLog,
      payload: {'uid': 'alice'},
    );
    for (var i = 0; i < kOutboxMaxPermanentFailures; i++) {
      await service.drain();
      await makeAllDue();
    }
    expect(await service.deadCount(), 1);
    await service.discard('m:1');
    expect(await dao.all(), isEmpty);
  });

  test('re-queuing a dead intent brings it back as pending', () async {
    await dao.enqueue(id: 'share:r1', kind: OutboxKind.shareRide, payload: {});
    await dao.recordFailure(
      id: 'share:r1',
      error: 'nope',
      nextAttemptAt: DateTime.now(),
      permanent: true,
      dead: true,
    );
    expect(await dao.pendingCount(), 0);

    await dao.enqueue(id: 'share:r1', kind: OutboxKind.shareRide, payload: {});
    final entry = (await dao.all()).single;
    expect(entry.isDead, isFalse);
    expect(entry.permanentFailures, 0);
    expect(await dao.pendingCount(), 1);
  });

  group('isPermanentOutboxError', () {
    test('classifies the four codes a retry cannot fix', () {
      for (final code in kOutboxPermanentErrorCodes) {
        expect(isPermanentOutboxError(rejected(code)), isTrue, reason: code);
      }
    });

    test('treats everything else as transient', () {
      expect(isPermanentOutboxError(rejected('unavailable')), isFalse);
      expect(isPermanentOutboxError(rejected('deadline-exceeded')), isFalse);
      expect(isPermanentOutboxError(Exception('socket')), isFalse);
    });
  });

  group('v14 → v16 migration', () {
    test('adds status/permanent_failures and keeps queued rows pending',
        () async {
      // Stand in for a pre-v16 phone: the outbox exactly as v10 created it.
      // (Rebuilt in place — `inMemoryDatabasePath` is one shared instance,
      // so opening a second connection would just reach setUp's schema.)
      final old = db;
      await old.execute('DROP TABLE outbox');
      await old.execute('''
        CREATE TABLE outbox (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          next_attempt_at TEXT,
          last_error TEXT
        )
      ''');
      await old.insert('outbox', {
        'id': 'share:before-upgrade',
        'kind': OutboxKind.shareRide,
        'payload': '{"userId":"alice"}',
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 7,
      });
      // Only the v16 step, twice: a re-run must be survivable.
      await DatabaseHelper.instance.upgradeSchemaForTesting(old, 15, 16);
      await DatabaseHelper.instance.upgradeSchemaForTesting(old, 15, 16);

      final entry = (await dao.all()).single;
      expect(entry.status, OutboxStatus.pending);
      expect(entry.permanentFailures, 0);
      expect(entry.attempts, 7);
      expect(await dao.pendingCount(), 1);
    });
  });
}
