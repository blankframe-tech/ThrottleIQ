import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/bike_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late BikeDao dao;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    dao = BikeDao();
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> insertBike({
    required String id,
    required String userId,
    String? imagePath,
    int synced = 1,
  }) async {
    await db.insert('bikes', {
      'id': id,
      'user_id': userId,
      'brand': 'Honda',
      'model': 'CBR',
      'image_path': imagePath,
      'synced': synced,
      'is_active': 1,
      'total_distance_m': 0,
      'ride_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  group('BikeDao image methods', () {
    test('updateImagePath updates image_path and sets synced = 0', () async {
      await insertBike(id: 'bike_1', userId: 'user_1', imagePath: '/local/path.jpg', synced: 1);

      await dao.updateImagePath('bike_1', 'https://res.cloudinary.com/bike.jpg');

      final bike = await dao.getById('bike_1');
      expect(bike, isNotNull);
      expect(bike!['image_path'], equals('https://res.cloudinary.com/bike.jpg'));
      expect(bike['synced'], equals(0));
    });

    test('getBikesWithLocalImages returns only bikes with non-URL local images for user', () async {
      // Bike with local path:
      await insertBike(id: 'bike_local', userId: 'user_1', imagePath: '/data/user/0/bike.jpg');
      // Bike with remote URL:
      await insertBike(id: 'bike_remote', userId: 'user_1', imagePath: 'https://res.cloudinary.com/bike.jpg');
      // Bike with null image:
      await insertBike(id: 'bike_null', userId: 'user_1', imagePath: null);
      // Bike with empty image:
      await insertBike(id: 'bike_empty', userId: 'user_1', imagePath: '');
      // Bike belonging to another user:
      await insertBike(id: 'bike_other_user', userId: 'user_2', imagePath: '/data/user/0/other.jpg');

      final localBikes = await dao.getBikesWithLocalImages('user_1');
      expect(localBikes.length, equals(1));
      expect(localBikes.first['id'], equals('bike_local'));
    });
  });
}
