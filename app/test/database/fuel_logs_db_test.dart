@Timeout(Duration(seconds: 30))
library;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/daos/fuel_log_dao.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/maintenance/data/models/fuel_log_model.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/fuel_provider.dart';

class _MockUser extends Mock implements User {
  @override
  String get uid => 'alice';
}

/// Fuel fill-ups against a real in-memory SQLite: schema v27, tombstones,
/// bike archive/delete handling, account deletion and the outbox payload.
void main() {
  sqfliteFfiInit();
  late Database db;
  final dao = FuelLogDao();

  Future<void> seedBike(String id, {String user = 'alice'}) =>
      db.insert('bikes', {
        'id': id,
        'user_id': user,
        'brand': 'Yamaha',
        'model': 'FZ',
        'created_at': '2026-01-01T00:00:00.000',
      });

  Map<String, dynamic> row(String id, String bikeId, {double odo = 1000}) => {
        'id': id,
        'bike_id': bikeId,
        'filled_at': '2026-09-01T10:00:00.000',
        'odometer_km': odo,
        'liters': 5.0,
        'total_cost': 650.0,
        'price_per_liter': 130.0,
        'full_tank': 1,
        'created_at': '2026-09-01T10:00:00.000',
        'updated_at': '2026-09-01T10:00:00.000',
        'synced': 0,
      };

  group('with the current schema', () {
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

    test('schemaVersion is at least 27', () {
      expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(27));
    });

    test('per-user queries go through the bike and include archived bikes',
        () async {
      await seedBike('b1');
      await seedBike('b2');
      await seedBike('bob-bike', user: 'bob');
      await db.update('bikes', {'archived': 1},
          where: 'id = ?', whereArgs: ['b2']);
      await dao.upsert(row('f1', 'b1'));
      await dao.upsert(row('f2', 'b2'));
      await dao.upsert(row('f3', 'bob-bike'));
      final mine = await dao.getAllForUser('alice');
      expect(mine.map((r) => r['id']).toSet(), {'f1', 'f2'});
      expect((await dao.unsyncedForUser('alice')), hasLength(2));
      await dao.markSynced('f1');
      expect((await dao.unsyncedForUser('alice')).single['id'], 'f2');
    });

    test('deleteWithTombstone drops the row and its queued upload', () async {
      await seedBike('b1');
      await dao.upsert(row('f1', 'b1'));
      await db.insert('outbox', {
        'id': FuelLogDao.outboxId('f1'),
        'kind': OutboxKind.fuelLog,
        'payload': '{}',
        'created_at': '2026-09-01',
      });
      await dao.deleteWithTombstone(['f1'], userId: 'alice');
      expect(await db.query('fuel_logs'), isEmpty);
      expect(await db.query('outbox'), isEmpty);
      expect(await dao.isDeleted('f1'), isTrue);
      expect(await dao.pendingRemoteDeletions('alice'), ['f1']);
      expect(await dao.pendingRemoteDeletions('bob'), isEmpty);
      await dao.markDeletionSynced('f1');
      expect(await dao.pendingRemoteDeletions('alice'), isEmpty);
      expect(await dao.deletedIds(), {'f1'});
    });

    test('archiving with fuel logs tombstones them; without keeps them',
        () async {
      await seedBike('b1');
      await seedBike('b2');
      await dao.upsert(row('f1', 'b1'));
      await dao.upsert(row('f2', 'b2'));
      await BikeDao().setArchived('b2', true);
      expect(await db.query('fuel_logs'), hasLength(2));

      await BikeDao().setArchived('b1', true, deleteFuelLogs: true);
      expect((await db.query('fuel_logs')).single['id'], 'f2');
      final t = await db.query('deleted_fuel_logs');
      expect(t.single['id'], 'f1');
      expect(t.single['user_id'], 'alice');
      expect(t.single['synced'], 0);
    });

    test('deleting a bike tombstones its fuel logs for the cloud', () async {
      await seedBike('b1');
      await dao.upsert(row('f1', 'b1'));
      await dao.upsert(row('f2', 'b1', odo: 1200));
      await BikeDao().delete('b1');
      expect(await db.query('fuel_logs'), isEmpty);
      expect((await dao.pendingRemoteDeletions('alice')).toSet(), {'f1', 'f2'});
    });

    test('deleteUserData removes only that rider\'s fuel data', () async {
      await seedBike('b1');
      await seedBike('bob-bike', user: 'bob');
      await dao.upsert(row('f1', 'b1'));
      await dao.upsert(row('f2', 'bob-bike'));
      await dao.deleteWithTombstone(['gone'], userId: 'alice');
      await DatabaseHelper.instance.deleteUserData('alice');
      expect((await db.query('fuel_logs')).single['id'], 'f2');
      expect(await db.query('deleted_fuel_logs'), isEmpty);
    });

    test('saving queues a {uid, log} outbox entry keyed fuel:<id>', () async {
      await seedBike('b1');
      final outbox = OutboxService(
        currentUid: () => 'alice',
        // Never reached: attemptNow runs this instead of Firestore.
        deliverOverride: (_) async => OutboxDeliveryResult.deferred,
      );
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_MockUser()),
        outboxServiceProvider.overrideWithValue(outbox),
      ]);
      addTearDown(c.dispose);
      final id = await c.read(fuelLogsProvider('b1').notifier).save(
            FuelLogDraft(
              filledAt: DateTime(2026, 9, 1, 10),
              odometerKm: 1000,
              liters: 5,
              totalCost: 650,
              pricePerLiter: 130,
              station: ' Meghna ',
            ),
          );
      // Let the fire-and-forget enqueue land.
      for (var i = 0; i < 20; i++) {
        if ((await db.query('outbox')).isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final entries = await OutboxDao().all();
      final entry = entries.singleWhere((e) => e.id == 'fuel:$id');
      expect(entry.kind, OutboxKind.fuelLog);
      expect(entry.payload['uid'], 'alice');
      final log = Map<String, dynamic>.from(entry.payload['log'] as Map);
      expect(log['id'], id);
      expect(log['bike_id'], 'b1');
      expect(log['station'], 'Meghna');
      // What the delivery writes to users/alice/fuelLogs/<id>.
      final cloud = FuelLogModel.toCloudPayload(log);
      expect(cloud.keys.toSet(),
          FuelLogModel.cloudKeys.toSet().difference({'note'}));
      expect(cloud['full_tank'], isTrue);
      expect(jsonEncode(cloud), isNot(contains('"synced"')));
      expect((await db.query('fuel_logs')).single['synced'], 0);
    });

    test('a queued upload of a deleted fill-up is discarded', () async {
      await dao.deleteWithTombstone(['f1'], userId: 'alice');
      final outbox = OutboxService(currentUid: () => 'alice');
      final result = await outbox.deliverForTesting(OutboxEntry(
        id: 'fuel:f1',
        kind: OutboxKind.fuelLog,
        payload: {
          'uid': 'alice',
          'log': row('f1', 'b1'),
        },
        createdAt: DateTime(2026, 9, 1),
        attempts: 0,
        nextAttemptAt: null,
        lastError: null,
      ));
      expect(result, OutboxDeliveryResult.discarded);
    });
  });

  group('v26 → v27 migration', () {
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // A v26 install's tables that matter here.
      await db.execute('''
        CREATE TABLE bikes (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
          brand TEXT NOT NULL, model TEXT NOT NULL, created_at TEXT NOT NULL)
      ''');
      await seedBike('b1');
    });

    tearDown(() async => db.close());

    Future<Set<String>> tables() async => (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type IN ('table','index')"))
        .map((r) => r['name'] as String)
        .toSet();

    test('creates fuel_logs, its index and tombstones; re-run is safe',
        () async {
      expect(await tables(), isNot(contains('fuel_logs')));
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 26, 27);
      expect(
          await tables(),
          containsAll(
              ['fuel_logs', 'deleted_fuel_logs', 'idx_fuel_logs_bike_filled']));
      await db.insert('fuel_logs', row('f1', 'b1'));

      // Idempotent: running the step again keeps the data.
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 26, 27);
      final rows = await db.query('fuel_logs');
      expect(rows.single['id'], 'f1');
      expect(rows.single['full_tank'], 1);
      expect((await db.query('bikes')).single['id'], 'b1');
    });

    test('an upgrade that stops before 27 does not create the tables',
        () async {
      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 25, 26);
      expect(await tables(), isNot(contains('fuel_logs')));
    });
  });
}
