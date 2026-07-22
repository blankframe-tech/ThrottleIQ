import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/slugify.dart';
import '../../domain/entities/forum_entity.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/entities/forum_reply_entity.dart';
import '../models/forum_model.dart';
import '../models/forum_post_model.dart';
import '../models/forum_reply_model.dart';

class ForumRepository {
  static final ForumRepository _instance = ForumRepository._internal();

  factory ForumRepository() => _instance;

  ForumRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _forums =>
      _firestore.collection('forums');

  CollectionReference<Map<String, dynamic>> get _forumFollows =>
      _firestore.collection('forum_follows');

  /// Resolves the forum for a brand (or brand+model), creating it on first
  /// use. The slug (`bikeForumSlug`) is deterministic, so concurrent callers
  /// (e.g. every rider who owns the same bike) always converge on the same
  /// doc. The existence check and the create are done inside a single
  /// transaction so two concurrent first-time callers can't both observe
  /// "doesn't exist" — Firestore retries a transaction on contention, so the
  /// loser re-reads, sees the doc now exists, and just returns it instead of
  /// racing a second `create` against the rules (which would otherwise be
  /// evaluated as an `update` and rejected).
  Future<ForumEntity> getOrCreateForum({required String brand, String? model}) async {
    final slug = bikeForumSlug(brand, model: model);
    final docRef = _forums.doc(slug);

    final hasModel = model != null && model.trim().isNotEmpty;
    final type = hasModel ? ForumType.bikeModel : ForumType.brand;
    final displayName = hasModel ? '$brand $model' : brand;

    final snapshot = await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(docRef);
      if (existing.exists) {
        return existing;
      }

      transaction.set(docRef, {
        'type': type.name,
        'brand': brand,
        'model': model,
        'displayName': displayName,
        'followerCount': 0,
        'postCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    });

    final doc = snapshot ?? await docRef.get();
    return ForumModel.fromFirestore(doc).toEntity();
  }

  /// Resolves a general (non-bike) topic forum, creating it on first use.
  /// Same create-if-missing transaction shape as [getOrCreateForum] — the
  /// slug is deterministic per topic, so repeated calls (e.g. every rider
  /// who taps "Maintenance") converge on the same doc.
  Future<ForumEntity> getOrCreateGeneralForum({required String topic}) async {
    final slug = generalForumSlug(topic);
    final docRef = _forums.doc(slug);

    final snapshot = await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(docRef);
      if (existing.exists) {
        return existing;
      }

      transaction.set(docRef, {
        'type': ForumType.general.name,
        'brand': '',
        'model': null,
        'topic': topic,
        'displayName': topic,
        'followerCount': 0,
        'postCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    });

    final doc = snapshot ?? await docRef.get();
    return ForumModel.fromFirestore(doc).toEntity();
  }

  /// Gets a forum by its slug/id, or null if it hasn't been created yet.
  Future<ForumEntity?> getForum(String forumId) async {
    final doc = await _forums.doc(forumId).get();
    if (!doc.exists) return null;
    return ForumModel.fromFirestore(doc).toEntity();
  }

  /// Follows a forum. Idempotent: checks the follow doc's existence inside a
  /// transaction so re-following never double-counts `followerCount` (same
  /// bug class as Phase 2's original `toggleLike`, fixed here up front).
  Future<void> followForum(String forumId, String userId) async {
    final followRef = _forumFollows.doc('${userId}_$forumId');
    final forumRef = _forums.doc(forumId);

    await _firestore.runTransaction((transaction) async {
      final followDoc = await transaction.get(followRef);
      if (followDoc.exists) return; // Already following.

      transaction.set(followRef, {
        'userId': userId,
        'forumId': forumId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(forumRef, {'followerCount': FieldValue.increment(1)});
    });
  }

  /// Unfollows a forum. Idempotent counterpart to [followForum].
  Future<void> unfollowForum(String forumId, String userId) async {
    final followRef = _forumFollows.doc('${userId}_$forumId');
    final forumRef = _forums.doc(forumId);

    await _firestore.runTransaction((transaction) async {
      final followDoc = await transaction.get(followRef);
      if (!followDoc.exists) return; // Already not following.

      transaction.delete(followRef);
      transaction.update(forumRef, {'followerCount': FieldValue.increment(-1)});
    });
  }

  Future<bool> isFollowing(String forumId, String userId) async {
    final doc = await _forumFollows.doc('${userId}_$forumId').get();
    return doc.exists;
  }

  /// Forums the given user follows.
  Future<List<ForumEntity>> getFollowedForums(String userId) async {
    final follows = await _forumFollows.where('userId', isEqualTo: userId).get();
    final forumIds = follows.docs
        .map((d) => d.data()['forumId'] as String?)
        .whereType<String>()
        .toList();
    if (forumIds.isEmpty) return [];

    final docs = await Future.wait(forumIds.map((id) => _forums.doc(id).get()));
    return docs
        .where((d) => d.exists)
        .map((d) => ForumModel.fromFirestore(d).toEntity())
        .toList();
  }

  /// Creates a post in a forum and bumps its `postCount`.
  Future<String> createPost({
    required String forumId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String title,
    required String body,
  }) async {
    final postRef = _forums.doc(forumId).collection('posts').doc();

    await postRef.set({
      'forumId': forumId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'replyCount': 0,
      'upvotes': 0,
      'downvotes': 0,
    });
    await _forums.doc(forumId).update({'postCount': FieldValue.increment(1)});

    return postRef.id;
  }

  Future<List<ForumPostEntity>> getPosts(String forumId) async {
    final snapshot = await _forums
        .doc(forumId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .get();

    final posts = snapshot.docs
        .map((doc) => ForumPostModel.fromFirestore(doc).toEntity())
        .toList();
    return _hydrateVotes(forumId, posts);
  }

  Future<ForumPostEntity?> getPost({
    required String forumId,
    required String postId,
  }) async {
    final doc = await _forums.doc(forumId).collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    final post = ForumPostModel.fromFirestore(doc).toEntity();
    final hydrated = await _hydrateVotes(forumId, [post]);
    return hydrated.first;
  }

  /// Hydrates the signed-in rider's vote state onto each post — entity-only,
  /// never stored on the post doc itself (mirrors
  /// RideShareRepository._hydrate's isLikedByCurrentUser/myVote pattern).
  Future<List<ForumPostEntity>> _hydrateVotes(
      String forumId, List<ForumPostEntity> posts) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || posts.isEmpty) return posts;

    final votes =
        await Future.wait(posts.map((p) => getMyPostVote(forumId, p.id, uid)));
    return [
      for (var i = 0; i < posts.length; i++) posts[i].copyWith(myVote: votes[i]),
    ];
  }

  /// The signed-in rider's own vote on a post, if any, read from
  /// `forums/{forumId}/posts/{postId}/votes/{uid}`.
  Future<int?> getMyPostVote(String forumId, String postId, String uid) async {
    final doc = await _forums
        .doc(forumId)
        .collection('posts')
        .doc(postId)
        .collection('votes')
        .doc(uid)
        .get();
    return doc.data()?['value'] as int?;
  }

  /// Casts, changes, or clears a vote on a post. Same bounded ±1-per-field
  /// transaction shape as RideShareRepository.vote, applied to
  /// `upvotes`/`downvotes` on the post doc.
  Future<void> votePost(String forumId, String postId, String uid, int value) async {
    assert(value == 1 || value == -1);
    final postRef = _forums.doc(forumId).collection('posts').doc(postId);
    final voteRef = postRef.collection('votes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(voteRef);
      final previous = existing.data()?['value'] as int?;
      if (previous == value) {
        transaction.delete(voteRef);
        transaction.update(postRef, {
          value == 1 ? 'upvotes' : 'downvotes': FieldValue.increment(-1),
        });
        return;
      }

      transaction.set(voteRef, {'value': value});
      if (previous == null) {
        transaction.update(postRef, {
          value == 1 ? 'upvotes' : 'downvotes': FieldValue.increment(1),
        });
      } else {
        transaction.update(postRef, {
          'upvotes': FieldValue.increment(value == 1 ? 1 : -1),
          'downvotes': FieldValue.increment(value == 1 ? -1 : 1),
        });
      }
    });
  }

  /// Adds a reply to a post and bumps its `replyCount`.
  Future<String> addReply({
    required String forumId,
    required String postId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String body,
  }) async {
    final postRef = _forums.doc(forumId).collection('posts').doc(postId);
    final replyRef = postRef.collection('replies').doc();

    await replyRef.set({
      'postId': postId,
      'forumId': forumId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.update({'replyCount': FieldValue.increment(1)});

    return replyRef.id;
  }

  Future<List<ForumReplyEntity>> getReplies({
    required String forumId,
    required String postId,
  }) async {
    final snapshot = await _forums
        .doc(forumId)
        .collection('posts')
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => ForumReplyModel.fromFirestore(doc).toEntity())
        .toList();
  }
}
