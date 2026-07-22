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

    test('returns null for an unrelated tag (e.g. a restaurant)', () {
      final candidate = service.parseElement({
        'id': 3,
        'lat': 23.81,
        'lon': 90.41,
        'tags': {'amenity': 'restaurant'},
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
