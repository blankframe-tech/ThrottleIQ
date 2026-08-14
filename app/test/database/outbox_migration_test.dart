@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Verifies the v9 → v10 upgrade (the `outbox` table) on the path a real
/// install takes.
///
/// Worth its own file because this is the migration that can brick an existing
/// rider: they already have a v9 database with rides in it, and a broken
/// `_onUpgrade` means the app falls into `_initDb`'s corrupt-file rescue, which
/// **deletes the database and rebuilds it** — silently taking every stored ride
/// with it. Testing through `createSchemaForTesting` would not catch that, since
/// that builds v10 directly and never runs the ladder.
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

  /// The parts of the v9 schema this migration has to coexist with. Written
  /// out by hand rather than pulled from the helper: the point is to stand in
  /// for what is on a rider's phone *before* the upgrade.
  Future<void> createV9Schema() async {
    await db.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        bike_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        distance_m REAL NOT NULL DEFAULT 0,
        avg_speed_ms REAL,
        max_speed_ms REAL,
        duration_s INTEGER,
        moving_s INTEGER,
        hard_brake_count INTEGER NOT NULL DEFAULT 0,
        rapid_accel_count INTEGER NOT NULL DEFAULT 0,
        high_jerk_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        map_snapshot_path TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  test('v9 → v10 adds the outbox table and keeps existing rides', () async {
    await createV9Schema();
    await db.insert('rides', {
      'id': 'ride-from-before-the-upgrade',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': DateTime.now().toIso8601String(),
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    });

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 9, 10);
    DatabaseHelper.overrideDatabaseForTesting(db);

    // The rider's data is still there — the thing a bad migration destroys.
    final rides = await db.query('rides');
    expect(rides, hasLength(1));
    expect(rides.single['id'], 'ride-from-before-the-upgrade');

    // ...and the new queue is usable immediately, not just present.
    final dao = OutboxDao();
    await dao.enqueue(
      id: 'share:ride-1',
      kind: OutboxKind.shareRide,
      payload: {'rideId': 'ride-1'},
    );
    expect(await dao.pendingCount(), 1);
  });

  test('the upgrade is idempotent if it runs twice', () async {
    // Belt and braces: sqflite shouldn't call _onUpgrade twice, but the
    // statements use IF NOT EXISTS precisely so that a re-run is survivable
    // rather than a crash on a table that already exists.
    await createV9Schema();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 9, 10);
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 9, 10);
    DatabaseHelper.overrideDatabaseForTesting(db);

    expect(await OutboxDao().pendingCount(), 0);
  });

  test('a fresh v10 install gets the same outbox table', () async {
    // The two schema paths (_onCreate for new installs, _onUpgrade for
    // existing ones) have to agree, or a bug only shows up on one of them.
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);

    final dao = OutboxDao();
    await dao.enqueue(id: 'a', kind: OutboxKind.liveSessionTeardown, payload: {});
    expect(await dao.pendingCount(), 1);
  });
}
