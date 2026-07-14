import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Clips a polyline by removing the first and last ~200m
/// to prevent home location leaks in shared rides.
class PrivacyZoneClipper {
  static const double privacyZoneDistanceMeters = 200.0;
  static const double earthRadiusMeters = 6371000.0;

  /// Clips the polyline by removing first/last ~200m segments.
  /// Returns a new list of LatLng points with endpoints removed.
  static List<LatLng> clipPolyline(List<LatLng> polyline) {
    if (polyline.length < 3) {
      return [];
    }

    final startClipIndex = _findClipIndex(polyline, 0, privacyZoneDistanceMeters);
    final endClipIndex = _findClipIndex(
      polyline,
      polyline.length - 1,
      privacyZoneDistanceMeters,
      reverse: true,
    );

    if (startClipIndex >= endClipIndex) {
      return [];
    }

    return polyline.sublist(startClipIndex, endClipIndex + 1);
  }

  /// Finds the index to start/end clipping at by walking along the polyline
  /// until we've covered the target distance.
  static int _findClipIndex(
    List<LatLng> polyline,
    int startIndex,
    double targetDistanceMeters, {
    bool reverse = false,
  }) {
    double accumulatedDistance = 0.0;
    int currentIndex = startIndex;

    if (!reverse) {
      while (currentIndex < polyline.length - 1) {
        final distance = haversineDistance(
          polyline[currentIndex],
          polyline[currentIndex + 1],
        );
        accumulatedDistance += distance;

        if (accumulatedDistance >= targetDistanceMeters) {
          return currentIndex + 1;
        }
        currentIndex++;
      }
      return polyline.length - 1;
    } else {
      while (currentIndex > 0) {
        final distance = haversineDistance(
          polyline[currentIndex],
          polyline[currentIndex - 1],
        );
        accumulatedDistance += distance;

        if (accumulatedDistance >= targetDistanceMeters) {
          return currentIndex - 1;
        }
        currentIndex--;
      }
      return 0;
    }
  }

  /// Haversine distance between two lat/lng points in meters.
  static double haversineDistance(LatLng point1, LatLng point2) {
    final lat1Rad = _toRadians(point1.latitude);
    final lat2Rad = _toRadians(point2.latitude);
    final deltaLat = _toRadians(point2.latitude - point1.latitude);
    final deltaLng = _toRadians(point2.longitude - point1.longitude);

    final a = (math.sin(deltaLat / 2) * math.sin(deltaLat / 2)) +
        (math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

}
