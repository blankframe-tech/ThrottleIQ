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
        final distance = _haversineDistance(
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
        final distance = _haversineDistance(
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
  static double _haversineDistance(LatLng point1, LatLng point2) {
    final lat1Rad = _toRadians(point1.latitude);
    final lat2Rad = _toRadians(point2.latitude);
    final deltaLat = _toRadians(point2.latitude - point1.latitude);
    final deltaLng = _toRadians(point2.longitude - point1.longitude);

    final a = (sin(deltaLat / 2) * sin(deltaLat / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }

  static double sin(double angle) {
    // Using Taylor series approximation for sin
    // For acceptable accuracy within our use case
    angle = angle % (2 * 3.14159265359);
    double result = 0;
    double term = angle;
    for (int i = 1; i < 10; i++) {
      result += term;
      term *= -angle * angle / ((2 * i) * (2 * i + 1));
    }
    return result;
  }

  static double cos(double angle) {
    // Using Taylor series approximation for cos
    angle = angle % (2 * 3.14159265359);
    double result = 1;
    double term = 1;
    for (int i = 1; i < 10; i++) {
      term *= -angle * angle / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double sqrt(double x) {
    if (x < 0) return 0;
    if (x == 0) return 0;
    double root = x / 2;
    for (int i = 0; i < 20; i++) {
      root = (root + x / root) / 2;
    }
    return root;
  }

  static double atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }

  static double _atan(double x) {
    // Using Tailor series for atan
    double result = 0;
    double power = x;
    for (int i = 0; i < 15; i++) {
      if (i % 2 == 0) {
        result += power / (2 * i + 1);
      } else {
        result -= power / (2 * i + 1);
      }
      power *= x * x;
    }
    return result;
  }
}
