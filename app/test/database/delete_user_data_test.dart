@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// docs/Issues.md §62.9: `DatabaseHelper.deleteUserData` used to wipe the
/// `outbox` table entirely, regardless of which user's row it was — on a
/// shared device, deleting account A's data silently destroyed account B's
/// still-pending outbox writes (an in-flight ride share, a maintenance log
/// sync). This suite pins the fix: an outbox row is now only removed if its
/// JSON payload actually claims to belong to the account being deleted.
void main() {
  sqfliteFfiInit();

  late Database db;
  late OutboxDao outboxDao;

  const userA = 'user-a';
  const userB = 'user-b';

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    outboxDao = OutboxDao();
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('deleteUserData only removes the target user\'s own outbox rows', () async {
    await outboxDao.enqueue(
      id: 'share:ride-a',
      kind: 'share_ride',
      payload: {'rideId': 'ride-a', 'userId': userA},
    );
    await outboxDao.enqueue(
      id: 'live-teardown:${userB}',
      kind: 'live_session_teardown',
      payload: {'uid': userB, 'token': 'tok'},
    );
    await outboxDao.enqueue(
      id: 'maintenance:log-b',
      kind: 'maintenance_log',
      payload: {'uid': userB, 'log': {'id': 'log-b'}},
    );

    await DatabaseHelper.instance.deleteUserData(userA);

    final remaining = await outboxDao.all();
    final remainingIds = remaining.map((e) => e.id).toSet();

    expect(remainingIds, {'live-teardown:$userB', 'maintenance:log-b'});
  });

  test('deleteUserData leaves an unparseable/legacy outbox row alone', () async {
    // A row whose payload can't be attributed to anyone must not be treated
    // as belonging to the account being deleted — see
    // DatabaseHelper._outboxPayloadOwner's doc comment.
    await db.insert('outbox', {
      'id': 'mystery-row',
      'kind': 'share_ride',
      'payload': 'not json',
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'next_attempt_at': null,
      'last_error': null,
    });

    await DatabaseHelper.instance.deleteUserData(userA);

    final remaining = await outboxDao.all();
    expect(remaining.map((e) => e.id), contains('mystery-row'));
  });

  test('deleteUserData still fully removes the target user\'s rides/bikes/profile', () async {
    final now = DateTime.now().toIso8601String();
    await db.insert('user_profiles', {
      'uid': userA,
      'display_name': 'A',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('bikes', {
      'id': 'bike-a',
      'user_id': userA,
      'brand': 'Yamaha',
      'model': 'R15',
      'is_active': 1,
      'synced': 1,
      'created_at': now,
    });
    await db.insert('rides', {
      'id': 'ride-a',
      'user_id': userA,
      'bike_id': 'bike-a',
      'status': 'completed',
      'start_time': now,
      'synced': 1,
      'created_at': now,
    });

    await DatabaseHelper.instance.deleteUserData(userA);

    expect(await db.query('user_profiles', where: 'uid = ?', whereArgs: [userA]), isEmpty);
    expect(await db.query('bikes', where: 'user_id = ?', whereArgs: [userA]), isEmpty);
    expect(await db.query('rides', where: 'user_id = ?', whereArgs: [userA]), isEmpty);
  });
}
