import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

void main() {
  group('PlaceEntity.osmId', () {
    test('is null for a rider-submitted place', () {
      final place = PlaceEntity(
        id: 'place1',
        name: 'Rahman Motors',
        category: PlaceCategory.garage,
        latitude: 23.81,
        longitude: 90.41,
        geohash: 'wh0r',
        address: 'Mirpur, Dhaka',
        createdBy: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(place.osmId, isNull);
    });

    test('is set for an OSM-imported place', () {
      final place = PlaceEntity(
        id: 'place2',
        name: 'Fuel Station',
        category: PlaceCategory.fuel,
        latitude: 23.81,
        longitude: 90.41,
        geohash: 'wh0r',
        address: '',
        createdBy: 'user1',
        createdAt: DateTime(2024, 1, 1),
        osmId: 'node/12345',
      );

      expect(place.osmId, 'node/12345');
      expect(place.props, contains('node/12345'));
    });
  });

  group('PlaceEntity dual ratings', () {
    test('defaults to 0.0 rating and 0 reviews for Google Maps', () {
      final place = PlaceEntity(
        id: 'place1',
        name: 'Local Pump',
        category: PlaceCategory.fuel,
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: 'Dhaka',
        createdBy: 'uid1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(place.googleRating, 0.0);
      expect(place.googleRatingCount, 0);
      expect(place.hasGoogleRating, isFalse);
      expect(place.hasThrottleIqRating, isFalse);
      expect(place.dualRatingDisplay, '0 + 0');
      expect(place.reviewsSummarySubtitle, 'No reviews yet');
    });

    test('formats x + y correctly when both ratings exist', () {
      final place = PlaceEntity(
        id: 'place2',
        name: 'Trust CNG',
        category: PlaceCategory.fuel,
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: 'Dhaka',
        createdBy: 'uid1',
        createdAt: DateTime(2024, 1, 1),
        googleRating: 4.3,
        googleRatingCount: 515,
        ratingSum: 14.0,
        ratingCount: 3, // average: 4.666... -> 4.7
      );

      expect(place.hasGoogleRating, isTrue);
      expect(place.hasThrottleIqRating, isTrue);
      expect(place.dualRatingDisplay, '4.3 + 4.7');
      expect(place.reviewsSummarySubtitle, '515 Google · 3 ThrottleIQ');
    });

    test('formats x + 0 correctly when only Google Maps rating exists', () {
      final place = PlaceEntity(
        id: 'place3',
        name: 'Moto Refresh BD',
        category: PlaceCategory.garage,
        latitude: 23.8,
        longitude: 90.4,
        geohash: 'wh0r',
        address: 'Dhaka',
        createdBy: 'uid1',
        createdAt: DateTime(2024, 1, 1),
        googleRating: 4.6,
        googleRatingCount: 185,
        ratingSum: 0,
        ratingCount: 0,
      );

      expect(place.hasGoogleRating, isTrue);
      expect(place.hasThrottleIqRating, isFalse);
      expect(place.dualRatingDisplay, '4.6 + 0');
      expect(place.reviewsSummarySubtitle, '185 Google · 0 ThrottleIQ');
    });
  });
}
