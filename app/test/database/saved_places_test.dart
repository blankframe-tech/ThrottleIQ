@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/poi_directory/data/repositories/saved_places_repository.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/domain/place_tags.dart';

/// Schema v21: Places-hub bookmarks (`saved_places`), exercised against a
/// real in-memory SQLite rather than a mocked DAO.
void main() {
  sqfliteFfiInit();

  late Database db;
  late SavedPlacesRepository repo;

  PlaceEntity place(String id, {String name = 'Rahman Motors', String? phone}) => PlaceEntity(
        id: id,
        name: name,
        category: PlaceCategory.garage,
        latitude: 23.81,
        longitude: 90.41,
        geohash: 'wh0r',
        address: 'Mirpur 10',
        phone: phone,
        verified: true,
        createdBy: 'someone',
        createdAt: DateTime(2025),
        ratingSum: 9,
        ratingCount: 2,
        tags: const {PlaceTag.efiDiagnostics, PlaceTag.punctureRepair},
      );

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    repo = SavedPlacesRepository();
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('schemaVersion is at least 21', () {
    expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(21));
  });

  test('save then read back a full offline snapshot, newest first', () async {
    await repo.save('u1', place('a', phone: '+880 1711-000000'), now: DateTime.utc(2026, 10, 1));
    await repo.save('u1', place('b', name: 'Second'), now: DateTime.utc(2026, 10, 2));

    final saved = await repo.savedPlaces('u1');
    expect([for (final p in saved) p.id], ['b', 'a']);

    final a = saved.last;
    expect(a.name, 'Rahman Motors');
    expect(a.category, PlaceCategory.garage);
    expect(a.latitude, 23.81);
    expect(a.address, 'Mirpur 10');
    expect(a.phone, '+880 1711-000000');
    expect(a.verified, isTrue);
    expect(a.tags, {PlaceTag.efiDiagnostics, PlaceTag.punctureRepair});
    // Ratings aren't snapshotted — they'd go stale.
    expect(a.ratingCount, 0);
  });

  test('re-saving refreshes details but keeps the original saved time', () async {
    await repo.save('u1', place('a'), now: DateTime.utc(2026, 10, 1));
    await repo.save('u1', place('b'), now: DateTime.utc(2026, 10, 2));
    await repo.save('u1', place('a', name: 'Rahman Motors (new)'), now: DateTime.utc(2026, 10, 3));

    final saved = await repo.savedPlaces('u1');
    expect([for (final p in saved) p.id], ['b', 'a'], reason: 'order unchanged');
    expect(saved.last.name, 'Rahman Motors (new)');
  });

  test('remove deletes only that bookmark', () async {
    await repo.save('u1', place('a'));
    await repo.save('u1', place('b'));
    await repo.remove('u1', 'a');
    expect([for (final p in await repo.savedPlaces('u1')) p.id], ['b']);
  });

  test('each rider has their own list, and deleteUserData wipes only theirs', () async {
    await repo.save('u1', place('a'));
    await repo.save('u2', place('a'));
    await repo.save('u2', place('b'));

    expect((await repo.savedPlaces('u1')).length, 1);
    expect((await repo.savedPlaces('u2')).length, 2);

    await DatabaseHelper.instance.deleteUserData('u2');
    expect((await repo.savedPlaces('u1')).length, 1);
    expect(await repo.savedPlaces('u2'), isEmpty);
  });

  test('the v20 → v21 upgrade adds the table to an existing install', () async {
    // A v20 install: the full schema minus this version's table.
    final old = db;
    await old.execute('DROP TABLE saved_places');
    final before = await old.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_places'");
    expect(before, isEmpty);

    await DatabaseHelper.instance.upgradeSchemaForTesting(old, 20, 21);
    // Survives a re-run, like every other step of the ladder.
    await DatabaseHelper.instance.upgradeSchemaForTesting(old, 20, 21);

    final after = await old.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_places'");
    expect(after, hasLength(1));
  });
}
