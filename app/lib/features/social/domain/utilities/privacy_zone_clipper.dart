import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/geo_math.dart';
import '../../../../core/utils/polyline_simplify.dart';

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
/// The hidden circle is NOT centred on the start (or end). A circle centred
/// on the start, even with a secret radius, gives itself away: the first
/// visible point of every share sits on its edge, and a circle fitted through
/// 3-6 shares recovers the centre (home) to within metres, without knowing
/// the radius. So each rider gets a secret *decoy*: the circle is centred on
/// start + an offset of 130-200 m on a secret bearing, and its radius is
/// offset + 200-349 m (330-549 m in all), so the true start is always at
/// least 200 m inside it. A perfect circle fit then finds only the decoy. The same offset is used
/// for the end point. Each share also loses a random 0-50 m extra, so the
/// first visible point does not sit exactly on the circle.
///
/// The offset, bearing and radius all come from the rider's salt in
/// `PrivacyZoneSalt`: a random value stored in an owner-only document. It
/// used to be derived from the uid, which defeated the whole point (see
/// [seedForUid] and issues §83.17). A salt nobody else can read is as good as
/// storing the offset itself, and needs no new field.
///
/// Only leading and trailing hidden runs are trimmed. A loop ride that
/// passes near home mid-ride keeps that middle section, since the share
/// model stores a single polyline and splitting it is a larger change.
class PrivacyZoneClipper {
  /// The least distance kept hidden around the true start and end; the
  /// per-rider jitter adds 0-149 m on top.
  static const double privacyZoneDistanceMeters = 200.0;

  /// Span of the per-rider jitter added to the base radius, in metres.
  static const int jitterSpanMeters = 150;

  /// Most random extra trim one share loses beyond the rider's radius.
  static const double maxExtraTrimMeters = 50.0;

  /// How far the decoy centre sits from the true endpoint: 130-200 m. The
  /// floor is above 100 m so a noisy fit near the decoy still misses home.
  static double offsetMetersFor(int seed) =>
      130.0 + (seed.abs() ~/ jitterSpanMeters) % 71;

  /// The decoy's bearing from the true endpoint, in degrees (-180..179).
  static double bearingFor(int seed) =>
      ((seed.abs() ~/ (jitterSpanMeters * 71)) % 360) - 180.0;

  /// Where the hidden circle around [endpoint] is centred for [seed].
  static LatLng hiddenCentre(LatLng endpoint, int seed) =>
      const Distance(calculator: Haversine())
          .offset(endpoint, offsetMetersFor(seed), bearingFor(seed));

  /// The hidden radius around [hiddenCentre] for a given [seed]: the decoy
  /// offset plus [radiusM] plus 0-149 m, so at least [radiusM] around the
  /// true endpoint stays hidden.
  static double radiusFor(int seed,
          {double radiusM = privacyZoneDistanceMeters}) =>
      offsetMetersFor(seed) + radiusM + (seed.abs() % jitterSpanMeters);

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

  /// Returns [polyline] with every leading point within the hidden circle
  /// around either endpoint removed (see [hiddenCentre] and [radiusFor]),
  /// and likewise every trailing point. [extraTrimM] widens both circles for
  /// this one ride. Returns an empty list when nothing is left outside the
  /// zones (a short ride, or one that never left the neighbourhood).
  static List<LatLng> clipPolyline(
    List<LatLng> polyline, {
    double radiusM = privacyZoneDistanceMeters,
    int seed = 0,
    double extraTrimM = 0,
  }) {
    if (polyline.length < 3) {
      return [];
    }

    final startCentre = hiddenCentre(polyline.first, seed);
    final endCentre = hiddenCentre(polyline.last, seed);
    final r = radiusFor(seed, radiusM: radiusM) + extraTrimM;
    bool hidden(LatLng p) =>
        haversineMetersLatLng(p, startCentre) <= r ||
        haversineMetersLatLng(p, endCentre) <= r;

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

  /// The polyline as written to a shared ride or public route: clipped
  /// FIRST, with a random 0-[maxExtraTrimMeters] extra trim, then simplified
  /// to at most [kSharedPolylineMaxPoints]. The simplifier only drops points,
  /// so nothing clipped can come back; the clip also needs the raw endpoints,
  /// which simplifying first would move.
  static List<LatLng> clipForSharing(List<LatLng> polyline,
          {int seed = 0, Random? random}) =>
      simplifyPolyline(clipPolyline(polyline,
          seed: seed,
          extraTrimM:
              (random ?? Random.secure()).nextDouble() * maxExtraTrimMeters));
}
