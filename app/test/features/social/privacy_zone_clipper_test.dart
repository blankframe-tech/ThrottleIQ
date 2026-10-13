import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/features/social/domain/utilities/privacy_zone_clipper.dart';

void main() {
  group('PrivacyZoneClipper', () {
    test('clips short polylines completely', () {
      final polyline = [
        const LatLng(40.7128, -74.0060), // NYC
        const LatLng(40.7130, -74.0058),
        const LatLng(40.7132, -74.0056),
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

    test('(a) GPS drift near home cannot walk the clip off the doorstep', () {
      // 300+ m of accumulated jitter, all within 10 m of the start (the
      // bike idling in the driveway). The old path-distance clipper counted
      // this as "200 m ridden" and started the shared line right at home.
      const home = LatLng(23.8103, 90.4125);
      final drift = <LatLng>[
        for (var k = 0; k < 40; k++)
          LatLng(
            home.latitude + (k.isEven ? 0.00008 : -0.00008), // ~9 m
            home.longitude,
          ),
      ];
      final ride = <LatLng>[
        home,
        ...drift,
        // Then 3 km due north, a point every ~50 m.
        for (var k = 1; k <= 60; k++)
          LatLng(home.latitude + 0.00045 * k, home.longitude),
      ];
      var drifted = 0.0;
      for (var k = 1; k <= drift.length; k++) {
        drifted += haversineMetersLatLng(ride[k - 1], ride[k]);
      }
      expect(drifted, greaterThan(300));

      for (final seed in [0, 7, 149, PrivacyZoneClipper.seedForUid('rider-1')]) {
        final r = PrivacyZoneClipper.radiusFor(seed);
        final clipped = PrivacyZoneClipper.clipPolyline(ride, seed: seed);
        expect(clipped, isNotEmpty);
        for (final p in clipped) {
          expect(haversineMetersLatLng(p, home), greaterThan(r));
          expect(haversineMetersLatLng(p, ride.last), greaterThan(r));
        }
      }
    });

    test('(b) a straight 5 km ride loses 200-350 m at each end', () {
      // ~5 km due north at ~11 m spacing.
      final ride = <LatLng>[
        for (var k = 0; k <= 450; k++) LatLng(0.0001 * k, 0.0),
      ];
      for (final uid in ['alice', 'bob', 'carol-uid-xyz']) {
        final seed = PrivacyZoneClipper.seedForUid(uid);
        final clipped = PrivacyZoneClipper.clipPolyline(ride, seed: seed);
        final trimmedStart = haversineMetersLatLng(ride.first, clipped.first);
        final trimmedEnd = haversineMetersLatLng(clipped.last, ride.last);
        for (final trimmed in [trimmedStart, trimmedEnd]) {
          expect(trimmed, greaterThanOrEqualTo(200));
          expect(trimmed, lessThanOrEqualTo(362)); // 350 m + one step
        }
      }
    });

    test('radius jitter is stable per rider and bounded to 200-349 m', () {
      expect(
        PrivacyZoneClipper.seedForUid('abc123'),
        PrivacyZoneClipper.seedForUid('abc123'),
      );
      final radii = {
        for (var i = 0; i < 200; i++)
          PrivacyZoneClipper.radiusFor(PrivacyZoneClipper.seedForUid('uid$i')),
      };
      expect(radii.length, greaterThan(50)); // actually varies across riders
      for (final r in radii) {
        expect(r, inInclusiveRange(200, 349));
      }
    });

    test('keeps a loop ride\'s middle even when it passes near home', () {
      // Out 1 km north, back to the start. Only leading/trailing runs are
      // trimmed, so the far half of the loop survives.
      final ride = <LatLng>[
        for (var k = 0; k <= 100; k++) LatLng(0.00009 * k, 0.0),
        for (var k = 99; k >= 0; k--) LatLng(0.00009 * k, 0.0001),
      ];
      final clipped = PrivacyZoneClipper.clipPolyline(ride);
      expect(clipped, isNotEmpty);
      expect(
        clipped.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        closeTo(0.009, 1e-9),
      );
    });

    test('empty polyline returns empty', () {
      final polyline = <LatLng>[];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('single point polyline returns empty', () {
      final polyline = [const LatLng(40.7128, -74.0060)];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });

    test('two point polyline returns empty', () {
      final polyline = [
        const LatLng(40.7128, -74.0060),
        const LatLng(40.7130, -74.0058),
      ];
      final clipped = PrivacyZoneClipper.clipPolyline(polyline);
      expect(clipped.isEmpty, true);
    });
  });
}
