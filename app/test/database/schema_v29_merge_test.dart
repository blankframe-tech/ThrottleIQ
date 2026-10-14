import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Schema v29: the merge of two different v28s. The sync round's v28 added
/// `updated_at`, touch triggers and UTC ride times; `main`'s v28 added
/// `impact_events` and two ride columns. A phone can be on either, or on
/// v27, and every path must end at the same schema without losing a row.
void main() {
  sqfliteFfiInit();

  late Database db;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  // Pre-v28 rows: device-local times with no offset.
  const start = '2026-10-13T08:15:00.000';
  const end = '2026-10-13T09:00:30.500';

  Future<void> seedV27() async {
    await db.execute('''
      CREATE TABLE bikes (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        created_at TEXT NOT NULL, last_ride_at TEXT, archived_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0)
    ''');
    await db.execute('''
      CREATE TABLE rides (id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        bike_id TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT,
        distance_m REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
    ''');
    await db.execute('''
      CREATE TABLE maintenance_logs (id TEXT PRIMARY KEY,
        bike_id TEXT NOT NULL, service_type TEXT NOT NULL,
        date TEXT NOT NULL, odometer_km REAL NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
    ''');
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u',
      'created_at': '2026-01-01T10:00:00.000',
      'synced': 1,
    });
    await db.insert('rides', {
      'id': 'r1',
      'user_id': 'u',
      'bike_id': 'b1',
      'start_time': start,
      'end_time': end,
      'distance_m': 12345.6,
      'status': 'completed',
      'synced': 1,
      'created_at': start,
    });
    await db.insert('maintenance_logs', {
      'id': 'm1',
      'bike_id': 'b1',
      'service_type': 'oilChange',
      'date': '2026-09-01T00:00:00.000',
      'odometer_km': 1500,
      'synced': 1,
      'created_at': '2026-09-01T12:00:00.000',
    });
  }

  /// `main`'s v28 as it shipped: its own impact_events and ride columns, no
  /// sync stamps. Only the columns this test reads.
  Future<void> seedMainV28() async {
    await seedV27();
    await db.execute('ALTER TABLE rides ADD COLUMN phone_placement TEXT');
    await db.execute('ALTER TABLE rides ADD COLUMN imu_rate_hz REAL');
    await db
        .update('rides', {'phone_placement': 'pocket', 'imu_rate_hz': 49.8});
    await db.execute('''
      CREATE TABLE impact_events (id TEXT PRIMARY KEY, ride_id TEXT NOT NULL,
        user_id TEXT, at TEXT NOT NULL, tier INTEGER NOT NULL, label TEXT,
        consent_research INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)
    ''');
    await db.insert('impact_events', {
      'id': 'e1',
      'ride_id': 'r1',
      'user_id': 'u',
      'at': '2026-10-13T02:30:00.000Z',
      'tier': 1,
      'label': 'fell',
      'created_at': '2026-10-13T02:30:00.000Z',
    });
  }

  Future<Map<String, Object?>> ride() async =>
      (await db.query('rides', where: 'id = ?', whereArgs: ['r1'])).single;

  Future<Set<String>> columns(String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((c) => c['name'] as String)
          .toSet();

  Future<List<Object?>> triggers() async => (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name"))
      .map((r) => r['name'])
      .toList();

  /// What every path into v29 must produce.
  Future<void> expectV29({required String placement}) async {
    expect(await columns('rides'),
        containsAll(['updated_at', 'phone_placement', 'imu_rate_hz']));
    expect(await columns('impact_events'), containsAll(['id', 'ride_id']));
    expect(await triggers(), [
      'bikes_touch_updated_at',
      'maintenance_logs_touch_updated_at',
      'rides_touch_updated_at',
    ]);
    final r = await ride();
    expect(r['distance_m'], 12345.6);
    expect(r['synced'], 1, reason: 'an upgrade is not an edit');
    expect(r['start_time'], DateTime.parse(start).toUtc().toIso8601String());
    expect(r['end_time'], DateTime.parse(end).toUtc().toIso8601String());
    expect(r['updated_at'], r['end_time']);
    expect(r['phone_placement'], placement == 'none' ? isNull : placement);
    expect((await db.query('bikes')).single['updated_at'], isNotNull);
    expect((await db.query('maintenance_logs')).single['odometer_km'], 1500);
  }

  test('schemaVersion is 29', () {
    expect(DatabaseHelper.schemaVersion, 29);
  });

  test('27 → 29: both steps run', () async {
    await seedV27();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 27, 29);
    await expectV29(placement: 'none');
  });

  test('the sync round\'s 28 → 29 adds impact_events, keeps every stamp',
      () async {
    await seedV27();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 27, 28);
    expect(await columns('rides'), isNot(contains('phone_placement')));
    // An edit made on v28, waiting to upload.
    await db.update('rides', {
      'distance_m': 12345.6,
      'synced': 0,
      'updated_at': '2026-10-14T00:00:00.000Z'
    });
    final before = await ride();

    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 28, 29);

    final after = await ride();
    for (final k in ['start_time', 'end_time', 'updated_at', 'synced']) {
      expect(after[k], before[k], reason: k);
    }
    expect(await columns('impact_events'), contains('tier'));
    expect(await triggers(), hasLength(3));
  });

  test('main\'s 28 → 29 adds the sync stamps, keeps impacts and placement',
      () async {
    await seedMainV28();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 28, 29);
    await expectV29(placement: 'pocket');
    final e = (await db.query('impact_events')).single;
    expect(e['id'], 'e1');
    expect(e['label'], 'fell');
  });

  test('main\'s 28 → 29 then a later edit is stamped', () async {
    await seedMainV28();
    await DatabaseHelper.instance.upgradeSchemaForTesting(db, 28, 29);
    final stamped = (await ride())['updated_at'];
    await db.update('rides', {'imu_rate_hz': 50.0, 'synced': 0});
    expect((await ride())['updated_at'], isNot(stamped));
  });
}
