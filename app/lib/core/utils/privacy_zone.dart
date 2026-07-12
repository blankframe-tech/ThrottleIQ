import 'package:latlong2/latlong.dart';

class PrivacyZone {
  static const double _homeBufferMeters = 200;

  /// Calculate great-circle distance between two points (Haversine)
  static double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;

  /// Clip home location: remove first & last N meters from polyline
  static List<LatLng> clipPrivacyZones(List<LatLng> polyline) {
    if (polyline.length < 2) return polyline;

    // Find distance from start until we've covered _homeBufferMeters
    int startClipIndex = 0;
    double distFromStart = 0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final dist = haversineDistance(
        polyline[i].latitude,
        polyline[i].longitude,
        polyline[i + 1].latitude,
        polyline[i + 1].longitude,
      );
      distFromStart += dist;
      if (distFromStart > _homeBufferMeters) {
        startClipIndex = i + 1;
        break;
      }
    }

    // Find distance from end until we've covered _homeBufferMeters
    int endClipIndex = polyline.length - 1;
    double distFromEnd = 0;
    for (int i = polyline.length - 1; i > 0; i--) {
      final dist = haversineDistance(
        polyline[i].latitude,
        polyline[i].longitude,
        polyline[i - 1].latitude,
        polyline[i - 1].longitude,
      );
      distFromEnd += dist;
      if (distFromEnd > _homeBufferMeters) {
        endClipIndex = i - 1;
        break;
      }
    }

    // Ensure valid range
    if (startClipIndex >= endClipIndex) {
      return polyline; // Not enough points to clip
    }

    return polyline.sublist(startClipIndex, endClipIndex + 1);
  }
}
