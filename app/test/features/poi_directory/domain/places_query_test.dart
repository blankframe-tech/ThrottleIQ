import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/domain/place_tags.dart';
import 'package:throttleiq/features/poi_directory/domain/places_query.dart';

// Rider at Farmgate, Dhaka. 0.009° of latitude ≈ 1 km.
const _lat = 23.7580;
const _lng = 90.3900;

PlaceEntity _place(
  String id, {
  String? name,
  PlaceCategory category = PlaceCategory.fuel,
  double kmNorth = 1,
  String address = '',
  bool verified = false,
  double ratingSum = 0,
  int ratingCount = 0,
  double googleRating = 0,
  Set<PlaceTag> tags = const {},
}) {
  return PlaceEntity(
    id: id,
    name: name ?? id,
    category: category,
    latitude: _lat + kmNorth * 0.009,
    longitude: _lng,
    geohash: '',
    address: address,
    verified: verified,
    createdBy: 'u',
    createdAt: DateTime(2026),
    ratingSum: ratingSum,
    ratingCount: ratingCount,
    googleRating: googleRating,
    tags: tags,
  );
}

List<String> _ids(List<PlaceHit> hits) => [for (final h in hits) h.place.id];

void main() {
  final places = [
    _place('shell', name: 'Shell Mirpur', kmNorth: 3, address: 'Mirpur 10', tags: {PlaceTag.open24h, PlaceTag.octane95}),
    _place('meghna', name: 'Meghna Fuel', kmNorth: 1, verified: true, tags: {PlaceTag.open24h}),
    _place('moto', name: 'Central Moto Works', category: PlaceCategory.garage, kmNorth: 2, ratingSum: 24, ratingCount: 5),
    _place('cafe', name: 'Biker Chai', category: PlaceCategory.recreation, kmNorth: 20, googleRating: 4.9),
    _place('cam', name: 'Speed camera', category: PlaceCategory.aiCamera, kmNorth: 0.5),
    _place('cop', name: 'Checkpost', category: PlaceCategory.police, kmNorth: 4),
  ];

  List<PlaceHit> run(PlacesQuery q) =>
      applyPlacesQuery(places, q, originLat: _lat, originLng: _lng);

  group('applyPlacesQuery', () {
    test('defaults: every destination within 25 km, nearest first, no safety points', () {
      expect(_ids(run(const PlacesQuery())), ['meghna', 'moto', 'shell', 'cafe']);
    });

    test('distances are computed once, in km', () {
      final hits = run(const PlacesQuery());
      expect(hits.first.distanceKm, closeTo(1.0, 0.05));
    });

    test('radius cuts off far places', () {
      expect(_ids(run(const PlacesQuery(radiusKm: 15))), ['meghna', 'moto', 'shell']);
      expect(_ids(run(const PlacesQuery(radiusKm: 5))), ['meghna', 'moto', 'shell']);
    });

    test('category narrows to one kind', () {
      expect(_ids(run(const PlacesQuery(category: PlaceCategory.fuel))), ['meghna', 'shell']);
    });

    test('search matches name, address, category and tags; every token must match', () {
      expect(_ids(run(const PlacesQuery(text: 'shell'))), ['shell']);
      expect(_ids(run(const PlacesQuery(text: 'mirpur'))), ['shell']);
      expect(_ids(run(const PlacesQuery(text: 'GARAGE'))), ['moto']);
      expect(_ids(run(const PlacesQuery(text: 'octane95'))), ['shell']);
      expect(_ids(run(const PlacesQuery(text: 'fuel open24h'))), ['meghna', 'shell']);
      expect(_ids(run(const PlacesQuery(text: 'shell garage'))), isEmpty);
    });

    test('search uses the localized labels it is given', () {
      final hits = applyPlacesQuery(
        places,
        const PlacesQuery(text: 'পাম্প'),
        originLat: _lat,
        originLng: _lng,
        categoryLabel: (c) => c == PlaceCategory.fuel ? 'ফুয়েল পাম্প' : c.name,
      );
      expect(_ids(hits), ['meghna', 'shell']);
    });

    test('search never surfaces a safety point', () {
      expect(run(const PlacesQuery(text: 'camera')), isEmpty);
    });

    test('verified-only and tags (all selected tags required)', () {
      expect(_ids(run(const PlacesQuery(verifiedOnly: true))), ['meghna']);
      expect(_ids(run(const PlacesQuery(tags: {PlaceTag.open24h}))), ['meghna', 'shell']);
      expect(_ids(run(const PlacesQuery(tags: {PlaceTag.open24h, PlaceTag.octane95}))), ['shell']);
    });

    test('rating sort prefers riders\' average, falls back to Google, ties by distance', () {
      expect(_ids(run(const PlacesQuery(sort: PlacesSort.rating))), ['cafe', 'moto', 'meghna', 'shell']);
    });

    test('without a fix nothing is cut by radius and order is by name', () {
      final hits = applyPlacesQuery(places, const PlacesQuery(radiusKm: 5));
      expect(_ids(hits), ['cafe', 'moto', 'meghna', 'shell']);
      expect(hits.every((h) => h.distanceKm == null), isTrue);
    });
  });

  group('countByCategory', () {
    test('counts every destination chip, ignoring the selected category', () {
      final counts = countByCategory(
        places,
        const PlacesQuery(category: PlaceCategory.garage),
        originLat: _lat,
        originLng: _lng,
      );
      expect(counts[null], 4);
      expect(counts[PlaceCategory.fuel], 2);
      expect(counts[PlaceCategory.garage], 1);
      expect(counts[PlaceCategory.recreation], 1);
      expect(counts[PlaceCategory.parts], 0);
      expect(counts.containsKey(PlaceCategory.aiCamera), isFalse);
      expect(counts.containsKey(PlaceCategory.police), isFalse);
    });

    test('respects search text and radius', () {
      final counts = countByCategory(
        places,
        const PlacesQuery(text: 'fuel', radiusKm: 5),
        originLat: _lat,
        originLng: _lng,
      );
      expect(counts[null], 2);
      expect(counts[PlaceCategory.fuel], 2);
      expect(counts[PlaceCategory.recreation], 0);
    });
  });

  group('PlacesQuery', () {
    test('activeRefinementCount counts only sheet-level refinements', () {
      expect(const PlacesQuery(text: 'x', category: PlaceCategory.fuel).activeRefinementCount, 0);
      expect(
        const PlacesQuery(
          verifiedOnly: true,
          sort: PlacesSort.rating,
          radiusKm: 50,
          tags: {PlaceTag.open24h, PlaceTag.octane95},
        ).activeRefinementCount,
        5,
      );
    });

    test('copyWith can clear the category', () {
      const q = PlacesQuery(category: PlaceCategory.parts);
      expect(q.copyWith(clearCategory: true).category, isNull);
      expect(q.copyWith(text: 'a').category, PlaceCategory.parts);
    });

    test('the radius options keep the old 25 km as the default', () {
      expect(placesRadiusOptionsKm, [5, 15, 25, 50]);
      expect(const PlacesQuery().radiusKm, 25);
    });
  });

  test('approxRideMinutes rounds up at city pace and never says 0', () {
    expect(approxRideMinutes(3.4), 7);
    expect(approxRideMinutes(0.01), 1);
    expect(approxRideMinutes(30), 60);
  });
}
