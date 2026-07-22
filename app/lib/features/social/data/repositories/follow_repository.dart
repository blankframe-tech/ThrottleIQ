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

  /// Uids that follow [uid].
  Future<List<String>> getFollowers(String uid) async {
    final snap = await _follows.where('followeeUid', isEqualTo: uid).get();
    return snap.docs
        .map((d) => d.data()['followerUid'] as String)
        .toList();
  }

  /// Uids that [uid] and each of them mutually follow (friends).
  Future<List<String>> getMutuals(String uid) async {
    final following = (await getFollowing(uid)).toSet();
    final followers = (await getFollowers(uid)).toSet();
    return following.intersection(followers).toList();
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
