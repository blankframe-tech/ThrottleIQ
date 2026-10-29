import 'package:throttleiq/core/utils/geo_math.dart';
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
    return haversineMeters(lat1, lng1, lat2, lng2) / 1000.0;
  }
}
