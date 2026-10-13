import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Mean Earth radius (IUGG), in metres. The one constant every great-circle
/// distance in the app is measured against.
const double earthRadiusMeters = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;

/// Great-circle distance between two WGS84 coordinates, in metres.
///
/// The single haversine for the app. There used to be six private copies
/// (routes, privacy clipper, POI repository, POI geohash utils, ride resume,
/// motion calculator), some in km and some in metres, which is how unit
/// mix-ups creep in. New code should call this, or [haversineMetersLatLng]
/// when it already holds [LatLng]s.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// [haversineMeters] for two [LatLng]s. Dart has no overloading, hence the
/// separate name.
double haversineMetersLatLng(LatLng a, LatLng b) =>
    haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);
