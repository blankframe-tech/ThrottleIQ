import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Supplies the per-rider secret that [PrivacyZoneClipper] jitters its hidden
/// radius with.
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

  /// Cached for the process lifetime — every share in a session reads it, and
  /// it cannot change once written.
  final Map<String, int> _cache = {};

  static const _field = 'zoneSalt';

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('privacy');

  /// The rider's salt, creating one on first use.
  ///
  /// Falls back to 0 (base radius, no jitter) if Firestore is unreachable —
  /// the ride still gets its 200 m clip, which is the part that actually hides
  /// the address. Silently skipping the clip entirely would be the wrong
  /// failure mode; a slightly-more-guessable radius is the right one.
  Future<int> forUid(String uid) async {
    final cached = _cache[uid];
    if (cached != null) return cached;

    try {
      final snap = await _doc(uid).get();
      final existing = snap.data()?[_field];
      if (existing is int) {
        _cache[uid] = existing;
        return existing;
      }

      final fresh = _random.nextInt(1 << 31);
      await _doc(uid).set({_field: fresh});
      _cache[uid] = fresh;
      return fresh;
    } catch (_) {
      // Offline, or the create raced another device and lost. Either way the
      // ride still gets the base 200 m clip; only the jitter is skipped, and
      // only for this attempt — the next share re-reads and picks up whatever
      // salt actually landed.
      return 0;
    }
  }
}
