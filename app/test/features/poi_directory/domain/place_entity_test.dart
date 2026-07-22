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
}
