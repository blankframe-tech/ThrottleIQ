import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/geohash_util.dart';
import 'package:throttleiq/features/poi_directory/data/ride_places_cache.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

/// issues §104.1: the live ride reads each cell once, then only deltas.
void main() {
  const lat = 23.8103, lng = 90.4125;

  PlaceEntity place(String id, {double dLat = 0, DateTime? expiresAt}) =>
      PlaceEntity(
        id: id,
        name: id,
        category: PlaceCategory.police,
        latitude: lat + dLat,
        longitude: lng,
        geohash: GeohashUtil.encode(lat + dLat, lng, precision: 9),
        address: '',
        createdBy: 'u',
        createdAt: DateTime.utc(2026, 10, 1),
        expiresAt: expiresAt,
      );

  late Directory dir;
  late DateTime now;
  late Map<String, PlaceEntity> server;
  late List<String> cellReads;
  late List<DateTime> deltaSince;
  (List<PlaceEntity>, DateTime?) delta = (const [], null);

  RidePlacesCache cache() => RidePlacesCache(
        file: Future.value(File('${dir.path}/cache.json')),
        clock: () => now,
        fetchCell: (cell) async {
          cellReads.add(cell);
          return [
            for (final p in server.values)
              if (p.geohash.startsWith(cell)) p,
          ];
        },
        fetchSince: (since) async {
          deltaSince.add(since);
          return delta;
        },
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ride_places_cache');
    now = DateTime.utc(2026, 10, 22, 10);
    server = {'a': place('a'), 'far': place('far', dLat: 0.5)};
    cellReads = [];
    deltaSince = [];
    delta = (const [], null);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('first refresh reads the cells; the next one only the delta', () async {
    final c = cache();
    await c.refresh(lat, lng, 10);
    expect(cellReads, isNotEmpty);
    expect((await c.nearby(lat, lng, 10)).map((p) => p.id), ['a']);

    cellReads.clear();
    final watermark = DateTime.utc(2026, 10, 22, 11);
    delta = ([place('new', dLat: 0.01)], watermark);
    now = now.add(const Duration(hours: 2));
    await c.refresh(lat, lng, 10);
    expect(cellReads, isEmpty);
    expect((await c.nearby(lat, lng, 10)).map((p) => p.id), ['a', 'new']);

    delta = (const [], null);
    await c.refresh(lat, lng, 10);
    expect(deltaSince.last, watermark, reason: 'server time, not the clock');
  });

  test('survives a restart without touching the network', () async {
    await cache().refresh(lat, lng, 10);
    cellReads.clear();
    final reopened = cache();
    expect((await reopened.nearby(lat, lng, 10)).map((p) => p.id), ['a']);
    expect(cellReads, isEmpty);
  });

  test('a stale cell is re-read and drops places deleted on the server',
      () async {
    final c = cache();
    await c.refresh(lat, lng, 10);
    server.remove('a');
    now = now.add(RidePlacesCache.cellMaxAge);
    await c.refresh(lat, lng, 10);
    expect(await c.nearby(lat, lng, 10), isEmpty);
  });

  test('offline keeps what was cached', () async {
    await cache().refresh(lat, lng, 10);
    final offline = RidePlacesCache(
      file: Future.value(File('${dir.path}/cache.json')),
      clock: () => now,
      fetchCell: (_) => throw const SocketException('offline'),
      fetchSince: (_) => throw const SocketException('offline'),
    );
    await expectLater(offline.refresh(lat, lng, 10), throwsA(anything));
    expect((await offline.nearby(lat, lng, 10)).map((p) => p.id), ['a']);
  });

  test('expired checkposts are dropped', () async {
    server['gone'] =
        place('gone', expiresAt: now.add(const Duration(hours: 1)));
    final c = cache();
    await c.refresh(lat, lng, 10);
    expect((await c.nearby(lat, lng, 10)).length, 2);
    now = now.add(const Duration(hours: 2));
    expect((await c.nearby(lat, lng, 10)).map((p) => p.id), ['a']);
  });

  test('clear forgets everything, on disk too', () async {
    final c = cache();
    await c.refresh(lat, lng, 10);
    await c.clear();
    expect(await c.nearby(lat, lng, 10), isEmpty);
    expect(await cache().nearby(lat, lng, 10), isEmpty,
        reason: 'a fresh instance reads the (deleted) file');
    cellReads.clear();
    await c.refresh(lat, lng, 10);
    expect(cellReads, isNotEmpty, reason: 'cleared cells are read again');
  });

  test('a fresh coarse cell covers the finer cells inside it', () async {
    final c = cache();
    await c.refresh(lat, lng, 25); // Places tab: coarser cells
    cellReads.clear();
    await c.refresh(lat, lng, 5); // ride: finer cells, same area
    expect(cellReads, isEmpty);
  });

  test('refreshes and clears run one at a time', () async {
    final c = cache();
    await Future.wait([
      c.refresh(lat, lng, 10),
      c.clear(),
      c.refresh(lat, lng, 10),
    ]);
    expect((await c.nearby(lat, lng, 10)).map((p) => p.id), ['a']);
  });
}
