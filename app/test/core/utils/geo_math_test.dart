import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/features/poi_directory/data/utils/geohash_utils.dart';

void main() {
  group('haversineMeters', () {
    test('is zero for a point against itself', () {
      expect(haversineMeters(23.81, 90.41, 23.81, 90.41), 0);
    });

    test('measures a known short hop', () {
      // 0.001° of latitude is ~111.2 m anywhere on the globe.
      expect(haversineMeters(23.810, 90.41, 23.811, 90.41), closeTo(111.2, 0.5));
    });

    test('~100 m of longitude at the equator', () {
      expect(haversineMeters(0, 0, 0, 0.0008983), closeTo(100, 0.5));
    });

    test('Dhaka to Chattogram is ~215 km as the crow flies', () {
      expect(
        haversineMeters(23.8103, 90.4125, 22.3569, 91.7832),
        closeTo(215000, 3000),
      );
    });

    test('is symmetric', () {
      final there = haversineMeters(23.81, 90.41, 23.92, 90.52);
      final back = haversineMeters(23.92, 90.52, 23.81, 90.41);
      expect(there, closeTo(back, 0.0001));
    });

    test('LatLng overload agrees with the scalar form', () {
      const a = LatLng(23.81, 90.41);
      const b = LatLng(23.92, 90.52);
      expect(
        haversineMetersLatLng(a, b),
        haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude),
      );
    });

    test('GeohashUtils.calculateDistance is the same value in km', () {
      expect(
        GeohashUtils.calculateDistance(lat1: 23.81, lng1: 90.41, lat2: 23.92, lng2: 90.52),
        closeTo(haversineMeters(23.81, 90.41, 23.92, 90.52) / 1000, 1e-9),
      );
    });
  });
}
