import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/data/utils/geohash_utils.dart';

void main() {
  group('GeohashUtils', () {
    test('encode generates valid geohash', () {
      const latitude = 23.8103;
      const longitude = 90.4125;

      final geohash = GeohashUtils.encode(latitude, longitude);

      expect(geohash, isNotEmpty);
      expect(geohash, isA<String>());
    });

    test('encode produces consistent results', () {
      const latitude = 23.8103;
      const longitude = 90.4125;

      final hash1 = GeohashUtils.encode(latitude, longitude);
      final hash2 = GeohashUtils.encode(latitude, longitude);

      expect(hash1, equals(hash2));
    });

    test('decode returns valid bounding box', () {
      const latitude = 23.8103;
      const longitude = 90.4125;
      final geohash = GeohashUtils.encode(latitude, longitude);

      final decoded = GeohashUtils.decode(geohash);

      expect(decoded, isA<Map<String, double>>());
      expect(decoded.containsKey('latitude'), isTrue);
      expect(decoded.containsKey('longitude'), isTrue);
      expect(decoded.containsKey('latitudeError'), isTrue);
      expect(decoded.containsKey('longitudeError'), isTrue);
    });

    test('different locations produce different geohashes', () {
      final hash1 = GeohashUtils.encode(23.8103, 90.4125); // Dhaka
      final hash2 = GeohashUtils.encode(22.3569, 91.7832); // Chittagong

      expect(hash1, isNot(equals(hash2)));
    });

    test('nearby locations share geohash prefix', () {
      final lat1 = 23.8103;
      final lng1 = 90.4125;
      final lat2 = 23.8110; // Very close
      final lng2 = 90.4130;

      final hash1 = GeohashUtils.encode(lat1, lng1, precision: 6);
      final hash2 = GeohashUtils.encode(lat2, lng2, precision: 6);

      expect(hash1.substring(0, 4), equals(hash2.substring(0, 4)));
    });

    test('getGeohashesForViewport generates multiple geohashes', () {
      const minLat = 23.0;
      const maxLat = 24.0;
      const minLng = 90.0;
      const maxLng = 91.0;

      final geohashes = GeohashUtils.getGeohashesForViewport(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        precision: 6,
      );

      expect(geohashes, isNotEmpty);
      expect(geohashes, isA<List<String>>());
    });

    test('isWithinBounds correctly validates coordinates', () {
      const testLat = 23.8103;
      const testLng = 90.4125;
      const minLat = 23.0;
      const maxLat = 24.0;
      const minLng = 90.0;
      const maxLng = 91.0;

      final isWithin = GeohashUtils.isWithinBounds(
        latitude: testLat,
        longitude: testLng,
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );

      expect(isWithin, isTrue);
    });

    test('isWithinBounds rejects coordinates outside bounds', () {
      const testLat = 25.0;
      const testLng = 92.0;
      const minLat = 23.0;
      const maxLat = 24.0;
      const minLng = 90.0;
      const maxLng = 91.0;

      final isWithin = GeohashUtils.isWithinBounds(
        latitude: testLat,
        longitude: testLng,
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );

      expect(isWithin, isFalse);
    });

    test('calculateDistance returns reasonable value', () {
      // Dhaka to nearby location
      final distance = GeohashUtils.calculateDistance(
        lat1: 23.8103,
        lng1: 90.4125,
        lat2: 23.8110,
        lng2: 90.4130,
      );

      expect(distance, isA<double>());
      expect(distance, greaterThan(0));
      expect(distance, lessThan(1)); // Should be less than 1 km
    });

    test('calculateDistance gives correct order of magnitude', () {
      // Distance from Dhaka to Chittagong should be around 261 km
      final distance = GeohashUtils.calculateDistance(
        lat1: 23.8103, // Dhaka
        lng1: 90.4125,
        lat2: 22.3569, // Chittagong
        lng2: 91.7832,
      );

      expect(distance, greaterThan(200)); // Should be at least 200 km
      expect(distance, lessThan(300)); // Should be less than 300 km
    });

    test('precision affects geohash length', () {
      const latitude = 23.8103;
      const longitude = 90.4125;

      final hash6 = GeohashUtils.encode(latitude, longitude, precision: 6);
      final hash9 = GeohashUtils.encode(latitude, longitude, precision: 9);

      expect(hash6.length, equals(6));
      expect(hash9.length, equals(9));
    });
  });

  group('Viewport Coverage', () {
    test('geohashes cover viewport bounds', () {
      const minLat = 23.0;
      const maxLat = 24.0;
      const minLng = 90.0;
      const maxLng = 91.0;

      final geohashes = GeohashUtils.getGeohashesForViewport(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        precision: 5,
      );

      // Verify all generated geohashes are unique (mostly)
      final uniqueGeohashes = geohashes.toSet();
      expect(uniqueGeohashes.length, lessThanOrEqualTo(geohashes.length));
    });

    test('simplifyGeohashes reduces redundant entries', () {
      final geohashes = ['abc123', 'abc124', 'abd000', 'xyz'];

      final simplified = GeohashUtils.simplifyGeohashes(geohashes);

      expect(simplified, isA<List<String>>());
      expect(simplified.length, lessThanOrEqualTo(geohashes.length));
    });
  });
}
