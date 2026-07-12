import 'package:throttleiq/core/utils/geohash_util.dart';

class GeohashUtils {
  /// Generate geohash from latitude and longitude
  static String encode(double latitude, double longitude, {int precision = 9}) {
    return GeohashUtil.encode(latitude, longitude, precision: precision);
  }

  /// Decode geohash to get bounding box
  static Map<String, double> decode(String geohash) {
    final bounds = GeohashUtil.decodeBounds(geohash);
    // Return bounds instead of point + error (matches encoded data format)
    return {
      'latitude': (bounds['latMin']! + bounds['latMax']!) / 2,
      'longitude': (bounds['lngMin']! + bounds['lngMax']!) / 2,
      'latitudeError': (bounds['latMax']! - bounds['latMin']!) / 2,
      'longitudeError': (bounds['lngMax']! - bounds['lngMin']!) / 2,
    };
  }

  /// Get geohash prefixes for a viewport
  /// Returns a list of geohashes that cover the viewport
  static List<String> getGeohashesForViewport({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int precision = 6,
  }) {
    final geohashes = <String>{};

    // Generate geohashes for a grid of points within the viewport
    final latStep = (maxLat - minLat) / 4;
    final lngStep = (maxLng - minLng) / 4;

    for (int i = 0; i <= 4; i++) {
      for (int j = 0; j <= 4; j++) {
        final lat = minLat + (i * latStep);
        final lng = minLng + (j * lngStep);

        if (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng) {
          final geohash = encode(lat, lng, precision: precision);
          geohashes.add(geohash);
        }
      }
    }

    return geohashes.toList();
  }

  /// Simplify geohash list by removing redundant ones
  static List<String> simplifyGeohashes(List<String> geohashes) {
    if (geohashes.isEmpty) return [];

    geohashes.sort();
    final simplified = <String>[];

    for (final geohash in geohashes) {
      bool isSubset = false;
      for (final existing in simplified) {
        if (geohash.startsWith(existing)) {
          isSubset = true;
          break;
        }
      }
      if (!isSubset) {
        simplified.add(geohash);
      }
    }

    return simplified;
  }

  /// Get neighbors of a geohash
  static List<String> getNeighbors(String geohash) {
    final neighbors = <String>[];

    // Generate neighbors by modifying the geohash
    for (int i = geohash.length - 1; i >= 0; i--) {
      final prefix = geohash.substring(0, i);
      // This is a simplified approach; a full implementation would use
      // neighbor tables as in standard geohash algorithms
    }

    return neighbors;
  }

  /// Check if a point is within bounds
  static bool isWithinBounds({
    required double latitude,
    required double longitude,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;
  }

  /// Calculate distance between two points (in kilometers)
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371; // Earth radius in kilometers

    final dLat = _toRadian(lat2 - lat1);
    final dLng = _toRadian(lng2 - lng1);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadian(lat1)) *
            _cos(_toRadian(lat2)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    final distance = earthRadius * c;

    return distance;
  }

  static double _toRadian(double degree) {
    return degree * (3.141592653589793 / 180);
  }

  static double _sin(double rad) {
    // Taylor series approximation for sin
    var result = rad;
    var power = rad;
    for (int i = 1; i <= 5; i++) {
      power *= -rad * rad / ((2 * i) * (2 * i + 1));
      result += power;
    }
    return result;
  }

  static double _cos(double rad) {
    // Taylor series approximation for cos
    var result = 1.0;
    var power = 1.0;
    for (int i = 1; i <= 5; i++) {
      power *= -rad * rad / ((2 * i - 1) * (2 * i));
      result += power;
    }
    return result;
  }

  static double _atan2(double y, double x) {
    if (x > 0) {
      return (y / x).atan();
    } else if (x < 0 && y >= 0) {
      return (y / x).atan() + 3.141592653589793;
    } else if (x < 0 && y < 0) {
      return (y / x).atan() - 3.141592653589793;
    } else if (x == 0 && y > 0) {
      return 3.141592653589793 / 2;
    } else if (x == 0 && y < 0) {
      return -3.141592653589793 / 2;
    } else {
      return 0;
    }
  }

  static double _sqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    double s = x;
    double d = x;
    while (d > 1e-10) {
      s = (s + x / s) / 2;
      d = (x / (s * s) - 1).abs();
    }
    return s;
  }
}
