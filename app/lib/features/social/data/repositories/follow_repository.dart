import 'package:cloud_firestore/cloud_firestore.dart';

/// The user↔user follow graph (open follow — no accept step).
///
/// One document per edge at `follows/{followerUid}_{followeeUid}` so a rider
/// can only ever create/delete edges they originate (enforced in
/// firestore.rules). Follower/following counts are derived with Firestore
/// `count()` aggregation rather than denormalized counters, so no write ever
/// touches another user's document.
class FollowRepository {
  static final FollowRepository _instance = FollowRepository._internal();
  factory FollowRepository() => _instance;
  FollowRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection('follows');

  String _edgeId(String follower, String followee) => '${follower}_$followee';

  Future<void> follow(String followerUid, String followeeUid) async {
    if (followerUid == followeeUid) return;
    await _follows.doc(_edgeId(followerUid, followeeUid)).set({
      'followerUid': followerUid,
      'followeeUid': followeeUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollow(String followerUid, String followeeUid) async {
    await _follows.doc(_edgeId(followerUid, followeeUid)).delete();
  }

  Future<bool> isFollowing(String followerUid, String followeeUid) async {
    final doc = await _follows.doc(_edgeId(followerUid, followeeUid)).get();
    return doc.exists;
  }

  Stream<bool> watchIsFollowing(String followerUid, String followeeUid) {
    return _follows
        .doc(_edgeId(followerUid, followeeUid))
        .snapshots()
        .map((d) => d.exists);
  }

  /// Uids [uid] follows.
  Future<List<String>> getFollowing(String uid) async {
    final snap = await _follows.where('followerUid', isEqualTo: uid).get();
    return snap.docs
        .map((d) => d.data()['followeeUid'] as String)
        .toList();
  }

  /// Live view of [getFollowing]. The feed keys its "followed authors" source
  /// and the Following chip off this, so following someone takes effect
  /// immediately instead of after an app restart — the one-shot future used
  /// to be cached for the whole session and never invalidated by
  /// [follow]/[unfollow].
  Stream<List<String>> watchFollowing(String uid) {
    return _follows.where('followerUid', isEqualTo: uid).snapshots().map(
        (snap) => snap.docs
            .map((d) => d.data()['followeeUid'] as String?)
            .whereType<String>()
            .toList());
  }

  /// Uids that follow [uid].
  Future<List<String>> getFollowers(String uid) async {
    final snap = await _follows.where('followeeUid', isEqualTo: uid).get();
    return snap.docs
        .map((d) => d.data()['followerUid'] as String)
        .toList();
  }

  /// Up to [limit] uids that follow [uid] — a bounded sample for
  /// suggestions (issues §90.A5), not the whole list. No `orderBy`, so it
  /// rides the automatic single-field index.
  Future<List<String>> getFollowersSample(String uid, {int limit = 30}) async {
    final snap =
        await _follows.where('followeeUid', isEqualTo: uid).limit(limit).get();
    return snap.docs
        .map((d) => d.data()['followerUid'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Uids that [uid] and each of them mutually follow (friends).
  Future<List<String>> getMutuals(String uid) async {
    final following = (await getFollowing(uid)).toSet();
    final followers = (await getFollowers(uid)).toSet();
    return following.intersection(followers).toList();
  }

  /// Which of [candidates] follow [uid] back — i.e. the mutuals among a
  /// known set, without reading [uid]'s whole follower list.
  ///
  /// The feed uses this to decide which followed authors' `mutual` posts it
  /// may ask for (firestore.rules denies a per-author query naming `mutual`
  /// unless both edges exist — issues §88.1). `whereIn` caps at 30 values, so
  /// [candidates] is chunked; each chunk costs one read per matching edge
  /// (minimum one), not one per follower.
  Future<Set<String>> getFollowersAmong(
      String uid, Iterable<String> candidates) async {
    final ids = candidates.where((c) => c != uid).toList();
    if (ids.isEmpty) return const <String>{};
    const chunkSize = 30;
    final snaps = await Future.wait([
      for (var i = 0; i < ids.length; i += chunkSize)
        _follows
            .where('followeeUid', isEqualTo: uid)
            .where('followerUid',
                whereIn: ids.sublist(
                    i, i + chunkSize > ids.length ? ids.length : i + chunkSize))
            .get(),
    ]);
    return {
      for (final snap in snaps)
        for (final d in snap.docs)
          if (d.data()['followerUid'] is String)
            d.data()['followerUid'] as String,
    };
  }

  Future<int> followerCount(String uid) async {
    final agg =
        await _follows.where('followeeUid', isEqualTo: uid).count().get();
    return agg.count ?? 0;
  }

  Future<int> followingCount(String uid) async {
    final agg =
        await _follows.where('followerUid', isEqualTo: uid).count().get();
    return agg.count ?? 0;
  }
}
