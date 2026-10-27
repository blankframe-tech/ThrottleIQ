@Timeout(Duration(seconds: 20))
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/cloud_repository.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// critique oct27 #15: a bike whose local photo file is gone was uploaded
/// with `image_path: null` but kept its dead local path, so
/// getBikesWithLocalImages re-selected it and it re-uploaded every cycle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(Firebase.initializeApp);
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

  test('a missing photo file clears the local path, so it stops re-uploading',
      () async {
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Honda',
      'model': 'CBR',
      'image_path': '/gone/container/bike.jpg',
      'synced': 1,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    final dao = BikeDao();
    final picked = await dao.getBikesWithLocalImages('u1');
    expect(picked, hasLength(1));

    // The Firestore write itself fails here (no platform), which uploadBikes
    // logs per row; the local fix-up happens before it.
    await CloudRepository().uploadBikes('u1', picked);

    expect((await dao.getById('b1'))!['image_path'], isNull);
    expect(await dao.getBikesWithLocalImages('u1'), isEmpty);
  });
}
