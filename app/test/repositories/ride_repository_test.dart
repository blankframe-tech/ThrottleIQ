import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/repositories/ride_repository_impl.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late RideRepositoryImpl repository;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    repository = RideRepositoryImpl();
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('saveRide and getRideById round-trip successfully', () async {
    final now = DateTime(2026, 9, 1, 10, 0);
    final ride = RideEntity(
      id: 'ride-101',
      userId: 'user-1',
      bikeId: 'bike-1',
      startTime: now,
      endTime: now.add(const Duration(minutes: 30)),
      distanceM: 15000,
      avgSpeedMs: 8.33,
      maxSpeedMs: 15.0,
      durationSeconds: 1800,
      status: RideStatus.completed,
    );

    await repository.saveRide(ride);

    final retrieved = await repository.getRideById('ride-101');
    expect(retrieved, isNotNull);
    expect(retrieved!.id, 'ride-101');
    expect(retrieved.distanceM, 15000);
    expect(retrieved.userId, 'user-1');
  });

  test('getCompletedRidesForUser returns rides ordered descending', () async {
    final t1 = DateTime(2026, 9, 1, 10, 0);
    final t2 = DateTime(2026, 9, 2, 10, 0);

    await repository.saveRide(RideEntity(
      id: 'ride-1',
      userId: 'user-1',
      bikeId: 'bike-1',
      startTime: t1,
      distanceM: 5000,
      status: RideStatus.completed,
    ));

    await repository.saveRide(RideEntity(
      id: 'ride-2',
      userId: 'user-1',
      bikeId: 'bike-1',
      startTime: t2,
      distanceM: 10000,
      status: RideStatus.completed,
    ));

    final rides = await repository.getCompletedRidesForUser('user-1');
    expect(rides.length, 2);
    expect(rides.first.id, 'ride-2');
    expect(rides.last.id, 'ride-1');
  });

  test('deleteRide removes ride and points', () async {
    final now = DateTime(2026, 9, 1, 10, 0);
    await repository.saveRide(RideEntity(
      id: 'ride-to-delete',
      userId: 'user-1',
      bikeId: 'bike-1',
      startTime: now,
      distanceM: 5000,
      status: RideStatus.completed,
    ));

    await repository.deleteRide('ride-to-delete');
    expect(await repository.getRideById('ride-to-delete'), isNull);
  });
}
