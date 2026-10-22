// ignore_for_file: subtype_of_sealed_class (test-only Firestore stubs; no fake_cloud_firestore dep)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';

import '../realtime/in_memory_realtime_store.dart';

// Firestore stub: the session-doc update and pointer transaction just succeed;
// only the RTDB step is under test here.
class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<void> update(Object data) async {}
}

class _Col extends Fake implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Doc();
}

class _Firestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _Col();

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
          {Duration timeout = const Duration(seconds: 30),
          int maxAttempts = 5}) async =>
      null as T;
}

/// End-to-end through the queue: enqueue -> drain row -> RTDB node removal.
void main() {
  sqfliteFfiInit();
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

  Future<(OutboxService, InMemoryRealtimeStore, RealtimeServices)> build(
      {bool deny = false}) async {
    final store = InMemoryRealtimeStore();
    await store.set('live_shares/tok', {'uid': 'u1', 'expiresAt': 1});
    if (deny) store.denyPaths.add('live_shares');
    final realtime = RealtimeServices(
      store: store,
      connections: RealtimeConnectionManager(store, linger: Duration.zero),
      health: RealtimeHealthMonitor(store),
    );
    final service = OutboxService(
      dao: OutboxDao(),
      firestore: _Firestore(),
      currentUid: () => 'u1',
      realtime: realtime,
    );
    return (service, store, realtime);
  }

  test('allowed: teardown delivers, row leaves the queue, node is removed',
      () async {
    final (service, store, realtime) = await build();
    final delivered =
        await service.enqueueLiveSessionTeardown(uid: 'u1', token: 'tok');
    expect(delivered, isTrue);
    expect(store.valueAt('live_shares/tok'), isNull);
    expect(await OutboxDao().pendingCount(), 0);
    service.dispose();
    realtime.dispose();
  });

  test('RTDB remove rejected: teardown still delivers, node left for TTL',
      () async {
    final (service, store, realtime) = await build(deny: true);
    final delivered =
        await service.enqueueLiveSessionTeardown(uid: 'u1', token: 'tok');
    expect(delivered, isTrue);
    expect(store.valueAt('live_shares/tok'), isNotNull);
    expect(await OutboxDao().pendingCount(), 0);
    service.dispose();
    realtime.dispose();
  });
}
