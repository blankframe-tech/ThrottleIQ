import 'package:cloud_firestore/cloud_firestore.dart';

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
      'likes': 0,
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

    return snapshot.docs
        .map((doc) => ForumPostModel.fromFirestore(doc).toEntity())
        .toList();
  }

  Future<ForumPostEntity?> getPost({
    required String forumId,
    required String postId,
  }) async {
    final doc = await _forums.doc(forumId).collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return ForumPostModel.fromFirestore(doc).toEntity();
  }

  /// Adds a reply to a post and bumps its `replyCount`.
  Future<String> addReply({
    required String forumId,
    required String postId,
    required String userId,
    required String userName,
    required String body,
  }) async {
    final postRef = _forums.doc(forumId).collection('posts').doc(postId);
    final replyRef = postRef.collection('replies').doc();

    await replyRef.set({
      'postId': postId,
      'forumId': forumId,
      'userId': userId,
      'userName': userName,
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
