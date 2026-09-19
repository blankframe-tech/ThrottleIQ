import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/core/utils/geohash_util.dart';
import 'package:throttleiq/features/poi_directory/data/repositories/place_repository.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

/// `getNearbyPlaces` used to read the whole `places` collection. It now
/// fans out to geohash range queries; these tests run that query plan
/// against an in-memory fake of the range read and check what it fetched.
void main() {
  PlaceEntity place(String id, double lat, double lng,
          {PlaceCategory category = PlaceCategory.fuel}) =>
      PlaceEntity(
        id: id,
        name: id,
        category: category,
        latitude: lat,
        longitude: lng,
        geohash: GeohashUtil.encode(lat, lng, precision: 9),
        address: '',
        phone: '',
        hours: '',
        photoUrls: const [],
        verified: false,
        createdBy: 'u',
        createdAt: DateTime.utc(2026),
        ratingSum: 0,
        ratingCount: 0,
      );

  /// Mimics `where('geohash', >= prefix).where('geohash', < prefix + '~')`
  /// (plus the optional category equality) and records every doc it
  /// returns, i.e. every document the real query would have been billed for.
  ({
    Future<List<PlaceEntity>> Function(String, PlaceCategory?) fetch,
    Set<String> fetchedIds,
    List<String> prefixes,
  }) fakeFirestore(List<PlaceEntity> all) {
    final fetchedIds = <String>{};
    final prefixes = <String>[];
    Future<List<PlaceEntity>> fetch(String prefix, PlaceCategory? category) async {
      prefixes.add(prefix);
      final hits = all
          .where((p) =>
              p.geohash.compareTo(prefix) >= 0 &&
              p.geohash.compareTo('$prefix~') < 0 &&
              (category == null || p.category == category))
          .toList();
      fetchedIds.addAll(hits.map((p) => p.id));
      return hits;
    }

    return (fetch: fetch, fetchedIds: fetchedIds, prefixes: prefixes);
  }

  const dhakaLat = 23.8103, dhakaLng = 90.4125;
  // Metres north/east of Dhaka, as a lat/lng offset.
  double north(double m) => dhakaLat + m / 111320;
  double east(double m) =>
      dhakaLng + m / (111320 * math.cos(dhakaLat * math.pi / 180));

  test('5 km search never fetches a place 50 km away', () async {
    final all = [
      place('near-1km', north(1000), dhakaLng),
      place('near-4km', dhakaLat, east(4000)),
      place('edge-7km', north(7000), dhakaLng), // fetched maybe, filtered out
      place('far-50km-n', north(50000), dhakaLng),
      place('far-50km-e', dhakaLat, east(50000)),
      place('chattogram', 22.3569, 91.7832),
    ];
    final fake = fakeFirestore(all);

    final result = await PlaceRepository.nearbyViaGeohashRanges(
      latitude: dhakaLat,
      longitude: dhakaLng,
      radiusKm: 5,
      fetchRange: fake.fetch,
    );

    expect(result.map((p) => p.id), ['near-1km', 'near-4km']);
    expect(fake.fetchedIds, isNot(contains('far-50km-n')));
    expect(fake.fetchedIds, isNot(contains('far-50km-e')));
    expect(fake.fetchedIds, isNot(contains('chattogram')));
    // Precision 5 for a 5 km radius: the center cell and its neighbors.
    expect(fake.prefixes.every((p) => p.length == 5), isTrue);
    expect(fake.prefixes.length, lessThanOrEqualTo(GeohashUtil.maxCoverCells));
  });

  test('25 km search (the app\'s radius) still finds everything inside it',
      () async {
    final rng = math.Random(42);
    final all = <PlaceEntity>[
      for (var i = 0; i < 400; i++)
        place('p$i', north((rng.nextDouble() - 0.5) * 120000),
            east((rng.nextDouble() - 0.5) * 120000)),
    ];
    final fake = fakeFirestore(all);

    final result = await PlaceRepository.nearbyViaGeohashRanges(
      latitude: dhakaLat,
      longitude: dhakaLng,
      radiusKm: 25,
      fetchRange: fake.fetch,
    );

    final expected = all
        .where((p) =>
            haversineMeters(dhakaLat, dhakaLng, p.latitude, p.longitude) <=
            25000)
        .map((p) => p.id)
        .toSet();
    expect(expected, isNotEmpty);
    expect(result.map((p) => p.id).toSet(), expected);
    // Sorted nearest first, no duplicates.
    final d = [
      for (final p in result)
        haversineMeters(dhakaLat, dhakaLng, p.latitude, p.longitude)
    ];
    for (var i = 1; i < d.length; i++) {
      expect(d[i], greaterThanOrEqualTo(d[i - 1]));
    }
    expect(result.length, result.map((p) => p.id).toSet().length);
    // It did not read the whole 120 km box.
    expect(fake.fetchedIds.length, lessThan(all.length));
  });

  test('category filter is passed through to the range reads', () async {
    final all = [
      place('fuel', north(500), dhakaLng),
      place('cafe', north(600), dhakaLng, category: PlaceCategory.values.last),
    ];
    final fake = fakeFirestore(all);
    final result = await PlaceRepository.nearbyViaGeohashRanges(
      latitude: dhakaLat,
      longitude: dhakaLng,
      radiusKm: 5,
      category: PlaceCategory.fuel,
      fetchRange: fake.fetch,
    );
    expect(result.map((p) => p.id), ['fuel']);
    expect(fake.fetchedIds, {'fuel'});
  });

  group('GeohashUtil.coverCircle', () {
    test('every point within the radius falls in a returned cell', () {
      final rng = math.Random(7);
      for (final radiusKm in [1.0, 5.0, 25.0]) {
        final cells = GeohashUtil.coverCircle(dhakaLat, dhakaLng, radiusKm);
        expect(cells.length, lessThanOrEqualTo(GeohashUtil.maxCoverCells));
        final precision = cells.first.length;
        for (var i = 0; i < 2000; i++) {
          // Uniform-ish sample inside the circle.
          final bearing = rng.nextDouble() * 2 * math.pi;
          final m = math.sqrt(rng.nextDouble()) * radiusKm * 1000;
          final lat = north(m * math.cos(bearing));
          final lng = east(m * math.sin(bearing));
          if (haversineMeters(dhakaLat, dhakaLng, lat, lng) > radiusKm * 1000) {
            continue;
          }
          final hash = GeohashUtil.encode(lat, lng, precision: precision);
          expect(cells, contains(hash), reason: '$radiusKm km, ($lat, $lng)');
        }
      }
    });
  });
}
