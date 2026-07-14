import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/domain/utilities/privacy_zone_clipper.dart';

void main() {
  group('PrivacyZoneClipper', () {
    test('clips short polylines completely', () {
      final polyline = [
        LatLng(40.7128, -74.0060), // NYC
        LatLng(40.7130, -74.0058),
        LatLng(40.7132, -74.0056),
      ];

      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('clips first 200m from polyline', () {
      // Create a polyline with points ~100m apart
      // ~800m ride: clipping 200m from each end must leave a middle.
      final polyline = <LatLng>[
        for (int i = 0; i <= 8; i++) LatLng(0.0009 * i, 0.0), // ~100m apart
      ];

      final clipped = PrivacyZoneClipper.clipPolyline(polyline);

      // Should have at least 2 points left
      expect(clipped.isNotEmpty, true);
      // First clipped point should be around index 2-3
      expect(clipped.length, lessThan(polyline.length));
    });

    test('clips last 200m from polyline', () {
      // Create a polyline
      // ~800m ride: clipping 200m from each end must leave a middle.
      final polyline = <LatLng>[
        for (int i = 0; i <= 8; i++) LatLng(0.0009 * i, 0.0), // ~100m apart
      ];

      final clipped = PrivacyZoneClipper.clipPolyline(polyline);

      // Last clipped point should not be the last point
      expect(clipped.isNotEmpty, true);
      expect(
        clipped.last.latitude != polyline.last.latitude ||
            clipped.last.longitude != polyline.last.longitude,
        true,
      );
    });

    test('haversine distance calculation', () {
      final point1 = LatLng(0.0, 0.0);
      final point2 = LatLng(0.0, 0.0008983); // ~100m at equator

      final distance = PrivacyZoneClipper.haversineDistance(point1, point2);

      // Should be approximately 100m
      expect(distance, greaterThan(90));
      expect(distance, lessThan(110));
    });

    test('empty polyline returns empty', () {
      final polyline = <LatLng>[];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('single point polyline returns empty', () {
      final polyline = [LatLng(40.7128, -74.0060)];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('two point polyline returns empty', () {
      final polyline = [
        LatLng(40.7128, -74.0060),
        LatLng(40.7130, -74.0058),
      ];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });
  });
}
