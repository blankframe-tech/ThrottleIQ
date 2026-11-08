import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// §101.C9: next_attempt_at is written as UTC; legacy local-time rows still read.
void main() {
  sqfliteFfiInit();
  late Database db;
  late OutboxDao dao;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    dao = OutboxDao();
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('recordFailure stores a UTC timestamp', () async {
    await dao.enqueue(id: 'a', kind: 'k', payload: {'x': 1});
    final at = DateTime.now().add(const Duration(hours: 1));
    await dao.recordFailure(id: 'a', error: 'e', nextAttemptAt: at);
    final row = (await db.query('outbox')).single;
    expect((row['next_attempt_at'] as String).endsWith('Z'), isTrue);
    expect(await dao.due(), isEmpty);
    expect(
        await dao.due(now: at.add(const Duration(seconds: 1))), hasLength(1));
  });

  test('legacy local-time rows are still compared correctly', () async {
    await dao.enqueue(id: 'old', kind: 'k', payload: {'x': 1});
    await dao.enqueue(id: 'future', kind: 'k', payload: {'x': 1});
    final now = DateTime.now();
    String local(Duration d) => now.add(d).toIso8601String();
    await db.update(
        'outbox', {'next_attempt_at': local(const Duration(minutes: -1))},
        where: "id = 'old'");
    await db.update(
        'outbox', {'next_attempt_at': local(const Duration(minutes: 30))},
        where: "id = 'future'");
    expect((await dao.due(now: now)).map((e) => e.id), ['old']);
  });

  test('an undecodable payload row still loads on every read', () async {
    await dao.enqueue(id: 'bad', kind: 'k', payload: {'x': 1});
    await db.update('outbox', {'payload': '{not json'});
    expect((await dao.all()).single.payload, isEmpty);
    expect((await dao.all()).single.payload, isEmpty);
  });
}
