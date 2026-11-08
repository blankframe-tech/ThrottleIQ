import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/cloud/write_ack.dart';
import '../../../../core/utils/geo_math.dart';

/// Supplies the seeds [PrivacyZoneClipper] shapes its hidden circles from:
/// the decoy centre's offset and bearing, and the radius, per place.
///
/// ## One seed per place
///
/// A single per-rider seed gives the same decoy offset at every place. Then
/// a viewer who knows one place the rider rides to (a workplace, say) could
/// work that offset out there and apply it at home. So each endpoint gets
/// its own seed: HMAC-SHA256(salt, anchor), where the anchor is a point
/// stored for that place. An endpoint within [anchorReuseMeters] of a stored
/// anchor reuses the nearest one, otherwise it becomes a new anchor. A fixed
/// grid would be simpler, but a home near a cell edge would then flip
/// between two decoys, and two decoys around one home narrow it down.
///
/// ## Why this isn't derived from the uid
///
/// The jitter used to be `FNV-1a(uid) % 150`, computed by
/// `PrivacyZoneClipper.seedForUid`. Its stated purpose was to stop someone who
/// sees several of a rider's shares from intersecting the circle edges and
/// triangulating the centre — i.e. the rider's home.
///
/// That defence never held (issues §83.17). `userId` is a plaintext field on
/// every shared ride document the attacker is already reading, the hash is in
/// a source-available repo, and so the exact radius was one line of arithmetic
/// away:
///
/// ```dart
/// radiusFor(seedForUid(ride.userId))   // exact, no averaging needed
/// ```
///
/// Knowing `r` precisely makes triangulation *easier* than a fixed 200 m
/// would, because the first surviving polyline point then sits on a circle of
/// known radius. A secret the viewer can recompute is not a secret.
///
/// The salt is now a random value the rider's own device generates once and
/// keeps in an owner-only document. It is never published, never derived from
/// anything public, and — because it is stored server-side rather than in
/// `SharedPreferences` — survives a reinstall, so a rider doesn't hand out a
/// second circle edge by changing phones.
class PrivacyZoneSalt {
  PrivacyZoneSalt({FirebaseFirestore? firestore, Random? random})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final Random _random;

  static const _saltField = 'zoneSalt';
  static const _anchorsField = 'anchors';

  /// An endpoint this close to a stored anchor shares its decoy.
  static const double anchorReuseMeters = 1000.0;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('privacy');

  /// The seeds for the start and the end of [polyline], creating the salt
  /// and any new anchors on first use.
  ///
  /// Falls back to one-off random seeds (nothing stored) if Firestore is
  /// unreachable. The ride still gets its full clip; only this one share
  /// uses a different decoy. A fixed fallback such as 0 would put every
  /// offline share's decoy at a publicly known spot, and silently skipping
  /// the clip would be worse still.
  Future<(int, int)> seedsFor(String uid, List<LatLng> polyline) async {
    // Fewer than 3 points clip to nothing whatever the seed.
    if (polyline.length < 3) return (0, 0);
    try {
      final data = (await _doc(uid).get()).data() ?? const {};
      final update = <String, dynamic>{};
      var salt = data[_saltField];
      if (salt is! int) {
        salt = _random.nextInt(1 << 31);
        update[_saltField] = salt;
      }
      final anchors = readAnchors(data[_anchorsField]);
      final known = anchors.length;
      final seeds = seedsWith(salt, anchors, polyline.first, polyline.last);
      if (anchors.length > known) {
        update[_anchorsField] = FieldValue.arrayUnion([
          for (final a in anchors.skip(known))
            {'lat': a.latitude, 'lng': a.longitude},
        ]);
      }
      // Bounded: offline, the write is queued and lands later; the seeds
      // already match what it will store.
      if (update.isNotEmpty) {
        await ackOrQueued(_doc(uid).set(update, SetOptions(merge: true)));
      }
      return seeds;
    } catch (_) {
      // Offline with nothing cached, or a write error. The ride still gets a
      // full clip around a random decoy, for this attempt only.
      return (_random.nextInt(1 << 31), _random.nextInt(1 << 31));
    }
  }

  /// Seeds for [start] and [end] from [salt], looking each up in [anchors]
  /// and appending a new anchor for a place not seen before. Pure, so the
  /// tests (and scripts/oneoff/reclip_shared_routes.js, which mirrors it)
  /// can run it without Firestore.
  static (int, int) seedsWith(
      int salt, List<LatLng> anchors, LatLng start, LatLng end) {
    int seedAt(LatLng p) {
      var anchor = nearestAnchor(anchors, p);
      if (anchor == null) {
        anchor = roundAnchor(p);
        anchors.add(anchor);
      }
      return seedForAnchor(salt, anchor);
    }

    return (seedAt(start), seedAt(end));
  }

  /// The stored anchor nearest [p] within [anchorReuseMeters], or null.
  static LatLng? nearestAnchor(List<LatLng> anchors, LatLng p) {
    LatLng? best;
    var bestM = anchorReuseMeters;
    for (final a in anchors) {
      final m = haversineMetersLatLng(a, p);
      if (m <= bestM) {
        best = a;
        bestM = m;
      }
    }
    return best;
  }

  /// A new anchor: the endpoint to 3 decimals (~100 m), which is all the
  /// 1 km reuse radius needs.
  static LatLng roundAnchor(LatLng p) => LatLng(
      (p.latitude * 1000).round() / 1000, (p.longitude * 1000).round() / 1000);

  /// The seed for one place: the first 31 bits of HMAC-SHA256 keyed by the
  /// salt (as decimal text) over the anchor as "lat,lng" to 3 decimals.
  static int seedForAnchor(int salt, LatLng anchor) {
    final mac = Hmac(sha256, utf8.encode('$salt'))
        .convert(utf8.encode('${anchor.latitude.toStringAsFixed(3)},'
            '${anchor.longitude.toStringAsFixed(3)}'));
    final b = mac.bytes;
    return ((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]) & 0x7fffffff;
  }

  /// Anchors from the stored list of {lat, lng} maps; malformed rows dropped.
  static List<LatLng> readAnchors(Object? raw) => [
        if (raw is List)
          for (final m in raw)
            if (m is Map && m['lat'] is num && m['lng'] is num)
              LatLng(
                  (m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
      ];
}
