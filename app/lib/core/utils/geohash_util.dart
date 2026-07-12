/// Geohash utility for spatial indexing (null-safe, no external dependency)
class GeohashUtil {
  static const String _base32 = "0123456789bcdefghjkmnpqrstuvwxyz";

  /// Encode latitude/longitude to geohash string
  /// precision: 1-12 (higher = more precise, larger string)
  static String encode(double lat, double lng, {int precision = 7}) {
    double latMin = -90.0, latMax = 90.0;
    double lngMin = -180.0, lngMax = 180.0;
    StringBuffer geohash = StringBuffer();
    bool isEven = true;
    int bits = 0, bit = 0;

    while (geohash.length < precision) {
      if (isEven) {
        double mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          bit |= (1 << (4 - bits));
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        double mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          bit |= (1 << (4 - bits));
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      isEven = !isEven;
      if (bits < 4) {
        bits++;
      } else {
        geohash.write(_base32[bit]);
        bits = 0;
        bit = 0;
      }
    }
    return geohash.toString();
  }

  /// Decode geohash to get bounding box (for viewport queries)
  static Map<String, double> decodeBounds(String geohash) {
    double latMin = -90.0, latMax = 90.0;
    double lngMin = -180.0, lngMax = 180.0;
    bool isEven = true;

    for (String c in geohash.split('')) {
      int idx = _base32.indexOf(c);
      for (int i = 4; i >= 0; i--) {
        int bit = (idx >> i) & 1;
        if (isEven) {
          double mid = (lngMin + lngMax) / 2;
          if (bit == 1) lngMin = mid;
          else lngMax = mid;
        } else {
          double mid = (latMin + latMax) / 2;
          if (bit == 1) latMin = mid;
          else latMax = mid;
        }
        isEven = !isEven;
      }
    }
    return {
      'latMin': latMin,
      'latMax': latMax,
      'lngMin': lngMin,
      'lngMax': lngMax,
    };
  }

  /// Get geohash prefix neighbors (for multi-precision queries)
  static List<String> getNeighbors(String geohash) {
    final neighbors = <String>[];
    final bounds = decodeBounds(geohash);
    final lat = (bounds['latMin']! + bounds['latMax']!) / 2;
    final lng = (bounds['lngMin']! + bounds['lngMax']!) / 2;
    final precision = geohash.length;

    final latOffset = bounds['latMax']! - bounds['latMin']!;
    final lngOffset = bounds['lngMax']! - bounds['lngMin']!;

    neighbors.add(encode(lat + latOffset, lng, precision: precision));
    neighbors.add(encode(lat - latOffset, lng, precision: precision));
    neighbors.add(encode(lat, lng + lngOffset, precision: precision));
    neighbors.add(encode(lat, lng - lngOffset, precision: precision));

    return neighbors.toSet().toList();
  }
}
