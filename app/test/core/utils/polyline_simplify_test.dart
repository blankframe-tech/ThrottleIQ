import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/core/utils/polyline_simplify.dart';
import 'package:throttleiq/features/social/data/models/ride_share_model.dart';
import 'package:throttleiq/features/social/domain/utilities/privacy_zone_clipper.dart';

/// A wiggly ~[n] × 3 m track (a 3 m GPS filter), so RDP can't collapse it.
/// [northward] keeps the heading within ±70° of north, so the ride never
/// doubles back past its start (the clipper only trims the two ends).
List<LatLng> _wigglyTrack(int n, {int seed = 1, bool northward = false}) {
  final rnd = math.Random(seed);
  var lat = 23.78, lng = 90.40, heading = 0.0;
  return [
    for (var i = 0; i < n; i++)
      () {
        heading = northward
            ? 0.9 * math.sin(i / 40) + (rnd.nextDouble() - 0.5) * 0.6
            : heading + (rnd.nextDouble() - 0.5) * 0.6;
        lat += math.cos(heading) * 3 / 111320;
        lng += math.sin(heading) * 3 / (111320 * math.cos(lat * math.pi / 180));
        return LatLng(lat, lng);
      }(),
  ];
}

void main() {
  group('simplifyPolyline', () {
    test('empty and single-point input come back unchanged', () {
      expect(simplifyPolyline(const []), isEmpty);
      const one = [LatLng(1, 2)];
      expect(simplifyPolyline(one), one);
    });

    test('a straight line collapses to its two endpoints', () {
      final line = [for (var i = 0; i <= 500; i++) LatLng(0.00003 * i, 0)];
      expect(simplifyPolyline(line), [line.first, line.last]);
    });

    test('a corner is kept', () {
      final corner = <LatLng>[
        for (var i = 0; i <= 100; i++) LatLng(0.0001 * i, 0), // ~1.1 km north
        for (var i = 1; i <= 100; i++) LatLng(0.01, 0.0001 * i), // then east
      ];
      final out = simplifyPolyline(corner);
      expect(out, [corner.first, corner[100], corner.last]);
    });

    test('a 20k-point track ends at most 1,000 points, first and last kept',
        () {
      final track = _wigglyTrack(20000);
      // Sanity: 5 m RDP alone isn't enough here, so the cap path is exercised.
      expect(simplifyPolyline(track, maxPoints: 1 << 30).length,
          greaterThan(1000));
      final out = simplifyPolyline(track);
      expect(out.length, lessThanOrEqualTo(kSharedPolylineMaxPoints));
      expect(out.first, track.first);
      expect(out.last, track.last);
    });

    test('decimates when even a wide tolerance leaves too many points', () {
      // Zig-zag of 5 km amplitude: every vertex survives any doubling.
      final zigzag = [
        for (var i = 0; i < 3000; i++) LatLng(i.isEven ? 0 : 0.05, 0.001 * i),
      ];
      final out = simplifyPolyline(zigzag);
      expect(out.length, lessThanOrEqualTo(kSharedPolylineMaxPoints));
      expect(out.first, zigzag.first);
      expect(out.last, zigzag.last);
    });
  });

  group('share payload polyline', () {
    test('is capped and never contains a point inside a privacy zone', () {
      final track = _wigglyTrack(20000, seed: 7, northward: true); // ~60 km
      const seed = 42;
      final r = PrivacyZoneClipper.radiusFor(seed);
      final shared = PrivacyZoneClipper.clipForSharing(track, seed: seed);

      final data = RideShareModel(
        id: 'r',
        userId: 'u',
        userName: 'n',
        userPhotoUrl: '',
        bikeId: 'b',
        bikeName: 'b',
        bikeType: 't',
        rideDate: DateTime(2026),
        distanceKm: 60,
        durationSeconds: 3600,
        maxSpeedKmh: 90,
        polyline: shared,
        createdAt: DateTime(2026),
      ).toFirestore();
      final written = [
        for (final m in (data['polyline'] as List).cast<Map<String, double>>())
          LatLng(m['lat']!, m['lng']!),
      ];

      expect(written, isNotEmpty);
      expect(written.length, lessThanOrEqualTo(kSharedPolylineMaxPoints));
      // Simplified after the clip: only points the clip kept can appear.
      final clipped =
          PrivacyZoneClipper.clipPolyline(track, seed: seed).toSet();
      expect(written.every(clipped.contains), isTrue);
      for (final p in written) {
        expect(haversineMetersLatLng(p, track.first), greaterThan(r));
        expect(haversineMetersLatLng(p, track.last), greaterThan(r));
      }
    });

    test('a full 1,000-point polyline stays small (size figure for rules)', () {
      // Worst case: every coordinate negative with full double precision.
      final poly = [
        for (var i = 0; i < kSharedPolylineMaxPoints; i++)
          LatLng(-89.12345678901234 + i * 1e-9, -179.12345678901234 + i * 1e-9),
      ];
      final encoded = RideShareModel(
        id: 'r',
        userId: 'u',
        userName: 'n',
        userPhotoUrl: '',
        bikeId: 'b',
        bikeName: 'b',
        bikeType: 't',
        rideDate: DateTime(2026),
        distanceKm: 0,
        durationSeconds: 0,
        maxSpeedKmh: 0,
        polyline: poly,
        createdAt: DateTime(2026),
      ).toFirestore()['polyline'];
      // Firestore storage size: per map 'lat'(4)+8 + 'lng'(4)+8 = 24 B.
      const firestoreBytes = kSharedPolylineMaxPoints * 24;
      final jsonBytes = utf8.encode(jsonEncode(encoded)).length;
      expect(firestoreBytes, 24000);
      expect(jsonBytes, lessThanOrEqualTo(53001)); // measured worst case
    });
  });
}
