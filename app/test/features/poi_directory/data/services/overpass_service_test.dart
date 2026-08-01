import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/data/services/overpass_service.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

void main() {
  final service = OverpassService();

  group('OverpassService.parseElement', () {
    test('maps amenity=fuel to PlaceCategory.fuel', () {
      final candidate = service.parseElement({
        'id': 123,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'amenity': 'fuel', 'name': 'Petro Bangla'},
      });

      expect(candidate, isNotNull);
      expect(candidate!.osmId, 'node/123');
      expect(candidate.category, PlaceCategory.fuel);
      expect(candidate.name, 'Petro Bangla');
    });

    test('maps craft=motorcycle_repair to PlaceCategory.garage', () {
      final candidate = service.parseElement({
        'id': 456,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'craft': 'motorcycle_repair'},
      });

      expect(candidate!.category, PlaceCategory.garage);
    });

    test('maps shop=motorcycle to PlaceCategory.parts', () {
      final candidate = service.parseElement({
        'id': 789,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'shop': 'motorcycle'},
      });

      expect(candidate!.category, PlaceCategory.parts);
    });

    test('falls back to a category label when the node has no name', () {
      final candidate = service.parseElement({
        'id': 1,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'amenity': 'fuel'},
      });

      expect(candidate!.name, PlaceCategory.fuel.displayName);
    });

    test('builds an address from addr:* tags, skipping missing ones', () {
      final candidate = service.parseElement({
        'id': 2,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {
          'amenity': 'fuel',
          'addr:street': 'Mirpur Road',
          'addr:city': 'Dhaka',
        },
      });

      expect(candidate!.address, 'Mirpur Road, Dhaka');
    });

    // A restaurant used to be "unrelated". It isn't any more: the recreation
    // category exists precisely to cover the biker-cafe / ride-out stop-off
    // kind of place, so food amenities now classify rather than being dropped.
    test('classifies a restaurant as recreation', () {
      final candidate = service.parseElement({
        'id': 3,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'amenity': 'restaurant'},
      });

      expect(candidate, isNotNull);
      expect(candidate!.category, PlaceCategory.recreation);
    });

    test('classifies a cafe as recreation', () {
      final candidate = service.parseElement({
        'id': 5,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'amenity': 'cafe', 'name': 'Highway Riders Cafe'},
      });

      expect(candidate, isNotNull);
      expect(candidate!.category, PlaceCategory.recreation);
      expect(candidate.name, 'Highway Riders Cafe');
    });

    test('classifies a viewpoint as recreation', () {
      final candidate = service.parseElement({
        'id': 6,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'tourism': 'viewpoint'},
      });

      expect(candidate, isNotNull);
      expect(candidate!.category, PlaceCategory.recreation);
    });

    test('still returns null for a genuinely unrelated tag', () {
      final candidate = service.parseElement({
        'id': 7,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'amenity': 'pharmacy'},
      });

      expect(candidate, isNull);
    });

    test('returns null when coordinates are missing', () {
      final candidate = service.parseElement({
        'id': 4,
        'tags': {'amenity': 'fuel'},
      });

      expect(candidate, isNull);
    });
  });
}
