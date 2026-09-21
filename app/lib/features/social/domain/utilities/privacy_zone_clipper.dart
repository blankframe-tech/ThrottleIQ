import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/geo_math.dart';

/// Hides the start and end of a shared ride so the polyline doesn't lead
/// back to the rider's front door.
///
/// This used to walk ~200 m of *path* in from each end. Path distance says
/// nothing about where the rider actually is: GPS drift while the bike sits
/// in the driveway can pile up 200 m of "distance" without leaving the gate,
/// and the clipped line then starts right at home. It now clips by *radius*:
/// every leading/trailing point within `r` metres (straight-line) of the
/// start or end is dropped, whatever route got it there.
///
/// `r` isn't a fixed 200 m either. A fixed radius lets anyone who sees a few
/// of a rider's shares intersect the circles' edges and triangulate the
/// center. Each rider gets a stable jitter on top of the base radius, so `r`
/// is 200-349 m — the same on every one of their rides, different per rider.
///
/// The jitter seed comes from `PrivacyZoneSalt`: a random value stored in an
/// owner-only document. It used to be derived from the uid, which defeated
/// the whole point — see [seedForUid] and issues §83.17.
///
/// Only leading and trailing hidden runs are trimmed. A loop ride that
/// passes near home mid-ride keeps that middle section, since the share
/// model stores a single polyline and splitting it is a larger change.
class PrivacyZoneClipper {
  /// Base radius; the per-rider jitter adds 0-149 m on top.
  static const double privacyZoneDistanceMeters = 200.0;

  /// Span of the per-rider jitter added to the base radius, in metres.
  static const int jitterSpanMeters = 150;

  /// The hidden radius for a given [seed]: [radiusM] plus 0-149 m.
  static double radiusFor(int seed,
          {double radiusM = privacyZoneDistanceMeters}) =>
      radiusM + (seed.abs() % jitterSpanMeters);

  /// A stable 31-bit seed for [uid] (FNV-1a over its UTF-16 code units).
  ///
  /// **Do not use this to seed a real clip.** The uid is a plaintext field on
  /// every shared ride document, and this function is in a source-available
  /// repo, so anyone reading the feed can recompute a rider's exact radius —
  /// which makes triangulating their home *easier* than a fixed radius would
  /// (issues §83.17). Use `PrivacyZoneSalt.forUid` instead.
  ///
  /// Kept only so the existing tests can still generate a deterministic,
  /// realistic-looking seed value without reaching for Firestore.
  @visibleForTesting
  static int seedForUid(String uid) {
    var hash = 0x811c9dc5;
    for (final unit in uid.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// Returns [polyline] with every leading point within the jittered radius
  /// of either endpoint removed, and likewise every trailing point. Returns
  /// an empty list when nothing is left outside the zones (a short ride, or
  /// one that never left the neighbourhood).
  static List<LatLng> clipPolyline(
    List<LatLng> polyline, {
    double radiusM = privacyZoneDistanceMeters,
    int seed = 0,
  }) {
    if (polyline.length < 3) {
      return [];
    }

    final start = polyline.first;
    final end = polyline.last;
    final r = radiusFor(seed, radiusM: radiusM);
    bool hidden(LatLng p) =>
        haversineMetersLatLng(p, start) <= r ||
        haversineMetersLatLng(p, end) <= r;

    var i = 0;
    while (i < polyline.length && hidden(polyline[i])) {
      i++;
    }
    var j = polyline.length - 1;
    while (j >= 0 && hidden(polyline[j])) {
      j--;
    }

    if (i >= j) {
      return [];
    }

    return polyline.sublist(i, j + 1);
  }
}
