import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/ride_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// Critique B12: a dismissed crash alert used to write `status: active`
/// through `finalizeRide`. [RideDao.setStatus] changes the status alone.
void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('rides', {
      'id': 'r1',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': '2026-10-14T08:00:00.000',
      'end_time': '2026-10-14T08:40:00.000',
      'distance_m': 12500.0,
      'max_speed_ms': 21.0,
      'duration_s': 2400,
      'moving_s': 2100,
      'status': 'crash',
      'synced': 1,
      'track_synced': 1,
      'created_at': '2026-10-14T08:00:00.000',
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('setStatus changes the status and leaves end_time and stats alone',
      () async {
    await RideDao().setStatus('r1', 'active');

    final row = (await RideDao().getById('r1'))!;
    expect(row['status'], 'active');
    expect(row['end_time'], '2026-10-14T08:40:00.000');
    expect(row['distance_m'], 12500.0);
    expect(row['max_speed_ms'], 21.0);
    expect(row['duration_s'], 2400);
    expect(row['moving_s'], 2100);
    expect(row['synced'], 1, reason: 'not re-flagged for upload');
    expect(row['track_synced'], 1);
  });

  test('setStatus on an unknown id is a no-op', () async {
    await RideDao().setStatus('missing', 'active');
    expect(await RideDao().getById('missing'), isNull);
    expect((await RideDao().getById('r1'))!['status'], 'crash');
  });
}
