import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/badges.dart';

// Client-maintained badge ownership counters in `stats/badges`.
//
// The Firebase project is on the Spark plan, so no Cloud Function can keep
// the aggregate (functions/src/badge-stats.ts is the Blaze-plan alternative
// and is not deployed). Each client bumps the counters itself, and
// firestore.rules makes every bump pay for itself with a one-way marker in
// the same batch:
//
// * `totalRiders` +1 together with `users/{uid}.badgeStatsCountedAt`
//   going from absent to set.
// * `owners.<id>` +1 together with `users/{uid}/earnedBadges/<id>.countedAt`
//   going from absent to set.
//
// Neither marker can be changed or removed afterwards, and a marked doc
// can't be deleted by its owner. So each rider is counted once and each
// (rider, badge) pair is counted once.
//
// **Sequencing.** Counting is tracked per marker, not per rider, so the
// order of the three paths doesn't matter and none of them double-counts:
//
// 1. Sign-up (ProfileRepository.ensureProfile) creates the profile with
//    the flag set, in the same batch as `totalRiders` +1.
// 2. A newly earned badge ([recordEarnedBadge]) creates its earnedBadges
//    doc with `countedAt` set, in the same batch as `owners.<id>` +1. That
//    doesn't depend on whether the rider has been counted yet.
// 3. The one-time self-count on app start ([selfCount]) registers a rider
//    whose profile has no flag, then counts each catalog earnedBadges doc
//    that has no `countedAt`: docs written by app versions before this
//    change. A badge counted by path 2 already carries `countedAt`, so the
//    backfill skips it, and the rules would reject a second bump anyway.
//
// The backfill takes one batch per counter rather than one batch for the
// whole rider: the rules can't loop over the keys of a map diff, so each
// stats write is checked against exactly one marker.
//
// If two devices race, the loser's batch is rejected as a whole (its
// marker is already set), so nothing is counted twice. If the rules aren't
// deployed yet, the batch is rejected and the plain write is retried
// without the counter; the self-count picks it up after the deploy.

/// Badge ids that count toward `stats/badges.owners`: the milestone catalog
/// in badges.dart. firestore.rules carries the same list
/// (`milestoneBadgeIds()`), checked by badge_catalog_parity_test.dart.
final Set<String> countedBadgeIds = {for (final def in badgeDefs) def.id};

bool isCountedBadgeId(String badgeId) => countedBadgeIds.contains(badgeId);

const String badgeStatsDocPath = 'stats/badges';

/// Field on `users/{uid}`: set once, when the rider is added to
/// `totalRiders`.
const String riderCountedField = 'badgeStatsCountedAt';

/// Field on `users/{uid}/earnedBadges/{id}`: set once, when the badge is
/// added to `owners.<id>`.
const String badgeCountedField = 'countedAt';

/// One document write in a batch, as plain data so the batch shapes can be
/// unit-tested without Firestore.
@immutable
class PlannedWrite {
  final String path;
  final Map<String, Object?> data;
  final bool merge;

  const PlannedWrite(this.path, this.data, {this.merge = true});

  @override
  String toString() => 'PlannedWrite($path, $data, merge: $merge)';
}

/// The batches that move a counter. Each is exactly the shape
/// firestore.rules accepts: one marker plus one +1.
abstract final class BadgeStatsBatches {
  /// Adds the rider to `totalRiders`. [profileFields] are merged into the
  /// same profile write, so sign-up creates the profile and counts it in
  /// one commit.
  static List<PlannedWrite> riderRegistration(
    String uid, {
    Map<String, Object?> profileFields = const {},
  }) =>
      [
        PlannedWrite('users/$uid', {
          ...profileFields,
          riderCountedField: FieldValue.serverTimestamp(),
        }),
        PlannedWrite(badgeStatsDocPath, {
          'totalRiders': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// Marks `earnedBadges/<badgeId>` counted and adds it to
  /// `owners.<badgeId>`. [isNew]: the doc is being created now, so it also
  /// gets its `earnedAt`; a backfilled doc keeps its original one.
  ///
  /// Both writes merge: the nested `owners` map merges key by key, so only
  /// `owners.<badgeId>` moves, and a create-or-update of the badge doc never
  /// drops fields already on it.
  static List<PlannedWrite> badgeCount(
    String uid,
    String badgeId, {
    required bool isNew,
  }) {
    if (!isCountedBadgeId(badgeId)) {
      throw ArgumentError.value(badgeId, 'badgeId', 'not a milestone badge');
    }
    return [
      PlannedWrite('users/$uid/earnedBadges/$badgeId', {
        'badgeId': badgeId,
        if (isNew) 'earnedAt': FieldValue.serverTimestamp(),
        badgeCountedField: FieldValue.serverTimestamp(),
      }),
      PlannedWrite(badgeStatsDocPath, {
        'owners': {badgeId: FieldValue.increment(1)},
        'lastCountedBadge': badgeId,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ];
  }
}

/// Whether a profile doc still needs adding to `totalRiders`. A missing
/// profile is not counted here: ensureProfile creates and counts it.
bool riderNeedsCounting(Map<String, dynamic>? profile) =>
    profile != null && profile[riderCountedField] == null;

/// Catalog badges the rider holds that were never counted, in catalog
/// order. [held] maps earnedBadges doc id to its data.
List<String> badgesNeedingCount(Map<String, Map<String, dynamic>> held) => [
      for (final def in badgeDefs)
        if (held.containsKey(def.id) &&
            held[def.id]![badgeCountedField] == null)
          def.id,
    ];

/// Applies the batches above. Every method is best-effort: badge display
/// never depends on the counters, so failures are logged and swallowed.
class BadgeStatsCounter {
  BadgeStatsCounter({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? _firestore;
  // Lazy, so constructing the counter in a test doesn't touch Firebase.
  FirebaseFirestore get _db => _firestore ??= FirebaseFirestore.instance;

  /// SharedPreferences key: this rider's self-count finished with nothing
  /// left to count, so later app starts skip the reads.
  @visibleForTesting
  static String doneKey(String uid) => 'badge_stats_self_counted_$uid';

  Future<void> commit(List<PlannedWrite> writes) {
    final batch = _db.batch();
    for (final w in writes) {
      batch.set(_db.doc(w.path), w.data, SetOptions(merge: w.merge));
    }
    return batch.commit();
  }

  /// The rider's earnedBadges docs, by id, read from the server so the
  /// "already counted?" decision isn't made on a stale cache.
  Future<Map<String, Map<String, dynamic>>> fetchHeldBadges(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('earnedBadges')
        .get(const GetOptions(source: Source.server));
    return {for (final d in snap.docs) d.id: d.data()};
  }

  /// Persists a badge the rider just earned and counts it, in one batch.
  /// Call only for a badge with no earnedBadges doc yet.
  Future<void> recordEarnedBadge(String uid, String badgeId) async {
    try {
      await commit(BadgeStatsBatches.badgeCount(uid, badgeId, isNew: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Rules not deployed yet, or another device already counted it. Keep
      // the durable record either way; a merge never touches countedAt.
      // The next self-count counts it if it's still uncounted.
      await _db.doc('users/$uid/earnedBadges/$badgeId').set({
        'badgeId': badgeId,
        'earnedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _clearDone(uid);
    }
  }

  /// Counts every held catalog badge that was never counted. Returns true
  /// when nothing is left uncounted.
  Future<bool> countHeldBadges(
    String uid,
    Map<String, Map<String, dynamic>> held,
  ) async {
    var allCounted = true;
    for (final id in badgesNeedingCount(held)) {
      try {
        await commit(BadgeStatsBatches.badgeCount(uid, id, isNew: false));
      } catch (e) {
        allCounted = false;
        debugPrint('[badgeStats] counting $id failed: $e');
      }
    }
    return allCounted;
  }

  /// One-time self-count for riders and badges that predate the counters.
  /// Runs on every sign-in / app start, but once it has finished it costs
  /// one SharedPreferences read.
  Future<void> selfCount(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(doneKey(uid)) == true) return;

      final profile = await _db
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server));
      // No profile yet: ensureProfile creates and counts it. Retry next time.
      var done = profile.exists;
      if (riderNeedsCounting(profile.data())) {
        try {
          await commit(BadgeStatsBatches.riderRegistration(uid));
        } catch (e) {
          done = false;
          debugPrint('[badgeStats] rider registration failed: $e');
        }
      }

      final held = await fetchHeldBadges(uid);
      if (!await countHeldBadges(uid, held)) done = false;

      if (done) await prefs.setBool(doneKey(uid), true);
    } catch (e) {
      debugPrint('[badgeStats] self-count failed: $e');
    }
  }

  Future<void> _clearDone(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(doneKey(uid));
    } catch (e) {
      debugPrint('[badgeStats] clearing the self-count flag failed: $e');
    }
  }
}
