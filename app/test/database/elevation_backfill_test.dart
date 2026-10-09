import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/data/repositories/elevation_backfill.dart';

/// Lazy elevation backfill for rides finalized before schema v26.
void main() {
  sqfliteFfiInit();

  late Database db;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    ElevationBackfill.resetForTesting();
  });
  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    ElevationBackfill.resetForTesting();
    await db.close();
  });

  Future<void> ride(String id,
      {String status = 'completed', double? gain, int synced = 1}) {
    return db.insert('rides', {
      'id': id,
      'user_id': 'u',
      'bike_id': 'b',
      'start_time': '2026-01-01T08:00:00.000',
      'status': status,
      'synced': synced,
      'elevation_gain_m': gain,
      'elevation_loss_m': gain,
      'created_at': '2026-01-01T08:00:00.000',
    });
  }

  Future<void> points(String id, List<double?> alts) async {
    final start = DateTime(2026, 1, 1, 8);
    final batch = db.batch();
    for (var i = 0; i < alts.length; i++) {
      batch.insert('ride_points', {
        'ride_id': id,
        'timestamp': start.add(Duration(seconds: i)).toIso8601String(),
        'lat': 23.8,
        'lng': 90.4,
        'speed_ms': 10.0,
        'altitude_m': alts[i],
      });
    }
    await batch.commit(noResult: true);
  }

  final climb = <double?>[for (var i = 0; i < 30; i++) 10.0 + i];
  final flat = <double?>[for (var i = 0; i < 30; i++) 50.0];

  Future<Map<String, Object?>> row(String id) async =>
      (await db.query('rides', where: 'id = ?', whereArgs: [id])).single;

  test('fills legacy rides from their points, in batches', () async {
    for (var i = 0; i < 7; i++) {
      await ride('climb$i');
      await points('climb$i', climb);
    }
    await ride('flat');
    await points('flat', flat);

    final n = await ElevationBackfill(batchSize: 3, pause: Duration.zero).run();
    expect(n, 8);
    for (var i = 0; i < 7; i++) {
      final r = await row('climb$i');
      expect(r['elevation_gain_m'] as double, greaterThan(20));
      expect(r['elevation_loss_m'], 0.0);
      expect(r['synced'], 0, reason: 'so the cloud copy gains it too');
    }
    final f = await row('flat');
    expect(f['elevation_gain_m'], 0.0);
    expect(f['elevation_loss_m'], 0.0);
  });

  test('leaves rides without points, or without usable altitude, NULL',
      () async {
    await ride('no-points');
    await ride('no-altitude');
    await points('no-altitude', [for (var i = 0; i < 30; i++) null]);
    await ride('sparse');
    await points('sparse', [for (var i = 0; i < 30; i++) i < 5 ? 10.0 : null]);

    expect(await ElevationBackfill(pause: Duration.zero).run(), 0);
    for (final id in ['no-points', 'no-altitude', 'sparse']) {
      expect((await row(id))['elevation_gain_m'], isNull, reason: id);
      expect((await row(id))['synced'], 1, reason: id);
    }
  });

  test('skips rides that already have a figure, and unfinished rides',
      () async {
    await ride('done', gain: 42);
    await points('done', climb);
    await ride('active', status: 'active');
    await points('active', climb);

    expect(await ElevationBackfill(pause: Duration.zero).run(), 0);
    expect((await row('done'))['elevation_gain_m'], 42.0);
    expect((await row('active'))['elevation_gain_m'], isNull);
  });

  test('runs at most once per app start', () async {
    await ride('a');
    await points('a', climb);
    expect(
        await ElevationBackfill.runOncePerStart(
            backfill: ElevationBackfill(pause: Duration.zero)),
        1);

    await ride('b');
    await points('b', climb);
    expect(
        await ElevationBackfill.runOncePerStart(
            backfill: ElevationBackfill(pause: Duration.zero)),
        0);
    expect((await row('b'))['elevation_gain_m'], isNull);
  });
}
