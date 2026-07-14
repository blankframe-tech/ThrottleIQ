import 'dart:math' as math;

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

  /// Get neighbors of a geohash (delegates to the core implementation)
  static List<String> getNeighbors(String geohash) =>
      GeohashUtil.getNeighbors(geohash);

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

  /// Calculate distance between two points (in kilometers, Haversine)
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371.0; // km

    final dLat = _toRadian(lat2 - lat1);
    final dLng = _toRadian(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadian(lat1)) *
            math.cos(_toRadian(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadian(double degree) => degree * (math.pi / 180);
}
