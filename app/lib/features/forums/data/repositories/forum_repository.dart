import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/slugify.dart';
import '../../domain/entities/forum_entity.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/entities/forum_reply_entity.dart';
import '../models/forum_model.dart';
import '../models/forum_post_model.dart';
import '../models/forum_reply_model.dart';

/// Deterministic doc id for a rider-created forum.
///
/// Prefixed with `c-` so a custom forum can never collide with a bike slug
/// (`yamaha__rx100`) or a topic slug (`maintenance`): those are produced by
/// `slugify.dart`, which emits `[a-z0-9_]` only, so the `-` puts custom
/// forums in a namespace that is disjoint by construction rather than by
/// convention.
String customForumSlug(String name) => 'c-${generalForumSlug(name)}';

/// Which of [candidates] should have their posts merged into [brand]'s
/// brand-level forum — pure logic factored out for testing (same pattern as
/// `garageForumTargets` in forum_providers.dart).
///
/// A forum qualifies only if it's a [ForumType.bikeModel] forum under
/// [brand] with at least one post — never the brand doc itself, never a
/// general/custom forum that happens to share the brand string, and never
/// an empty model forum (not worth a Firestore read for zero posts). This
/// only ever merges upward (model → brand); a brand forum's own posts never
/// appear inside a narrower model forum — see [ForumRepository.getPosts]'s
/// doc comment for why that direction is deliberate.
List<ForumEntity> modelForumsToMergeInto(String brand, List<ForumEntity> candidates) {
  return candidates
      .where((f) => f.type == ForumType.bikeModel && f.brand == brand && f.postCount > 0)
      .toList();
}

/// In-memory forum-name search over an already-fetched [forums] list — see
/// [ForumRepository.searchForums] for the ranking rules. Pure, so the Social
/// search can run it per keystroke against a cached list at zero reads.
List<ForumEntity> filterForumsByName(
  List<ForumEntity> forums,
  String query, {
  int limit = 20,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final matches = forums
      .where((forum) => forum.displayName.toLowerCase().contains(q))
      .toList()
    ..sort((a, b) {
      final aPrefix = a.displayName.toLowerCase().startsWith(q);
      final bPrefix = b.displayName.toLowerCase().startsWith(q);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      final byFollowers = b.followerCount.compareTo(a.followerCount);
      if (byFollowers != 0) return byFollowers;
      return a.displayName.compareTo(b.displayName);
    });
  return matches.take(limit).toList();
}

/// Posts fetched per page per source forum in a forum thread.
const int kForumPostsPageSize = 25;

/// One page of a forum's post list.
class ForumPostsPage {
  const ForumPostsPage({
    required this.posts,
    required this.cursor,
    required this.hasMore,
  });

  /// Newest first.
  final List<ForumPostEntity> posts;

  /// The `createdAt` the next page starts after, or null when empty.
  final DateTime? cursor;

  /// True while at least one source forum returned a full page.
  final bool hasMore;
}

/// Merges one page from each source forum without leaving holes — the same
/// k-way "horizon" merge the Social feed uses (`mergeFeedSources`): a source
/// that returned a full page may have more posts just older than its last
/// one, so nothing older than the newest such horizon is shown yet; it is
/// re-fetched (and de-duplicated by id) on the next page.
ForumPostsPage mergeForumPostPages(
  List<List<ForumPostEntity>> sources, {
  required int limit,
}) {
  final byId = <String, ForumPostEntity>{};
  DateTime? horizon;
  for (final source in sources) {
    for (final p in source) {
      byId[p.id] = p;
    }
    if (source.isNotEmpty && source.length >= limit) {
      final oldest = source
          .map((p) => p.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      if (horizon == null || oldest.isAfter(horizon)) horizon = oldest;
    }
  }
  final all = byId.values.toList()
    ..sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  if (horizon == null) {
    return ForumPostsPage(
      posts: all,
      cursor: all.isEmpty ? null : all.last.createdAt,
      hasMore: false,
    );
  }
  final cut = horizon;
  return ForumPostsPage(
    posts: [
      for (final p in all)
        if (!p.createdAt.isBefore(cut)) p,
    ],
    cursor: cut,
    hasMore: true,
  );
}

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
    // Same normalization bikeForumSlug applies to the slug — e.g. "FZS-Fi V3"
    // and "FZ-S V2" both slug to the same forum, so the stored model/display
    // name must say "FZS" too, not whichever rider's raw text happened to
    // create the doc first.
    final normalizedModel = hasModel ? normalizeModelFamily(brand, model) : null;
    final type = hasModel ? ForumType.bikeModel : ForumType.brand;
    final displayName = hasModel ? '$brand $normalizedModel' : brand;

    final snapshot = await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(docRef);
      if (existing.exists) {
        return existing;
      }

      transaction.set(docRef, {
        'type': type.name,
        'brand': brand,
        'model': normalizedModel,
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

  /// Creates a rider-owned forum. Unlike [getOrCreateForum] this is NOT
  /// create-if-missing: a name collision is a real error the rider needs to
  /// see ("pick another name"), not something to silently converge on —
  /// otherwise "create" would hand them someone else's forum, which they'd
  /// have no rights over. Same single-transaction existence check as
  /// [getOrCreateForum] so two riders racing the same name can't both
  /// observe "doesn't exist" and both believe they created it.
  Future<ForumEntity> createCustomForum({
    required String name,
    String? description,
    required String userId,
  }) async {
    final trimmed = name.trim();
    final slug = customForumSlug(trimmed);
    if (slug == 'c-') {
      throw ArgumentError('Forum name must contain at least one letter or digit');
    }

    final docRef = _forums.doc(slug);
    final trimmedDescription = description?.trim();

    final created = await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(docRef);
      if (existing.exists) return false;

      transaction.set(docRef, {
        'type': ForumType.custom.name,
        'brand': '',
        'model': null,
        'topic': null,
        'displayName': trimmed,
        'description':
            (trimmedDescription == null || trimmedDescription.isEmpty) ? null : trimmedDescription,
        'createdBy': userId,
        'maintainerIds': [userId],
        'followerCount': 0,
        'postCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!created) {
      throw StateError('A forum named "$trimmed" already exists');
    }

    final doc = await docRef.get();
    return ForumModel.fromFirestore(doc).toEntity();
  }

  /// Rider-created forums, newest first — the "Rider forums" discovery list.
  Future<List<ForumEntity>> getCustomForums({int limit = 50}) async {
    final snapshot = await _forums
        .where('type', isEqualTo: ForumType.custom.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => ForumModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Forums whose display name matches [query], for the Social header search.
  ///
  /// Firestore has no substring or case-insensitive matching, and forum docs
  /// carry no lowercased name field, so this fetches a bounded page of forums
  /// and filters in memory. Two consequences worth knowing:
  ///
  ///  * The query is a single-field `orderBy` with a `limit` and no `where`,
  ///    so it rides the automatic single-field index — no composite index to
  ///    deploy (the mistake this project has already paid for twice).
  ///  * It scans the [scanLimit] most-followed forums, not all of them. That
  ///    is fine while the whole board list is small; past that, the fix is a
  ///    `displayNameLower` field written at creation plus the same prefix
  ///    range query ProfileRepository.searchByUsername already uses for
  ///    usernames — a range plus an ordering on that one field, so still no
  ///    composite index, but it does need a backfill of every existing forum
  ///    doc.
  ///
  /// Prefix matches rank above mid-string ones ("roy" should surface "Royal
  /// Enfield" before "Vintage Royals"), then by follower count, then by name
  /// so the order is total and can't reshuffle between identical searches.
  ///
  /// Each call re-reads [scanLimit] forums. Interactive search should load
  /// [getForumsForSearch] once and run [filterForumsByName] per keystroke
  /// instead (issues §90.A7) — see the Social screen's forum search index.
  Future<List<ForumEntity>> searchForums(
    String query, {
    int scanLimit = 200,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    return filterForumsByName(
      await getForumsForSearch(scanLimit: scanLimit),
      query,
      limit: limit,
    );
  }

  /// The [scanLimit] most-followed forums — the corpus [searchForums]
  /// filters. Exposed so a caller can cache it across keystrokes.
  Future<List<ForumEntity>> getForumsForSearch({int scanLimit = 200}) async {
    final snapshot = await _forums
        .orderBy('followerCount', descending: true)
        .limit(scanLimit)
        .get();
    return snapshot.docs
        .map((doc) => ForumModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Grants [uid] moderation rights on a custom forum. `arrayUnion` keeps
  /// this idempotent — re-adding an existing maintainer is a no-op rather
  /// than a duplicate entry.
  Future<void> addMaintainer(String forumId, String uid) async {
    await _forums.doc(forumId).update({
      'maintainerIds': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeMaintainer(String forumId, String uid) async {
    await _forums.doc(forumId).update({
      'maintainerIds': FieldValue.arrayRemove([uid]),
    });
  }

  /// Deletes a post and rolls back the forum's `postCount`.
  ///
  /// Deliberately does NOT recurse into the post's `replies`/`votes`
  /// subcollections: Firestore has no client-side recursive delete, and
  /// fanning out a read+delete of every reply and vote from the phone is
  /// both slow and unbounded. Those docs are simply orphaned — nothing
  /// reads them once the parent post is gone (every query path goes
  /// through the post doc), so this is acceptable for beta. A Cloud
  /// Function triggered on post deletion should reap them later.
  ///
  /// The decrement carries the post's id in `lastPostId` so firestore.rules
  /// can tie the -1 to that post actually being deleted in this same batch
  /// (issues §90.D5/§90.D11). The rule used to allow -1 only for moderators,
  /// so a rider deleting their OWN post had the whole batch refused.
  Future<void> deletePost({required String forumId, required String postId}) async {
    final batch = _firestore.batch();
    batch.delete(_forums.doc(forumId).collection('posts').doc(postId));
    batch.update(_forums.doc(forumId), {
      'postCount': FieldValue.increment(-1),
      'lastPostId': postId,
    });
    await batch.commit();
  }

  /// Deletes a reply and rolls back its post's `replyCount`.
  Future<void> deleteReply({
    required String forumId,
    required String postId,
    required String replyId,
  }) async {
    final postRef = _forums.doc(forumId).collection('posts').doc(postId);
    // A batch is one atomic commit, same as a transaction as far as the rules
    // are concerned, so `lastReplyId` lets firestore.rules tie this -1 to the
    // reply actually being deleted here (issues §24.7/§24.11).
    final batch = _firestore.batch();
    batch.delete(postRef.collection('replies').doc(replyId));
    batch.update(postRef, {
      'replyCount': FieldValue.increment(-1),
      'lastReplyId': replyId,
    });
    await batch.commit();
  }

  /// Gets a forum by its slug/id, or null if it hasn't been created yet.
  Future<ForumEntity?> getForum(String forumId) async {
    final doc = await _forums.doc(forumId).get();
    if (!doc.exists) return null;
    return ForumModel.fromFirestore(doc).toEntity();
  }

  /// Follows a forum. Idempotent: checks the follow doc's existence inside a
  /// transaction so re-following never double-counts `followerCount` (same
  /// bug class as the old ride-share `toggleLike`, fixed here up front).
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

  /// Ids of the forums [userId] follows — the follow docs only, no forum doc
  /// reads (Pulse needs ids to page posts, not each forum's metadata).
  Future<List<String>> getFollowedForumIds(String userId) async {
    final follows = await _forumFollows.where('userId', isEqualTo: userId).get();
    return follows.docs
        .map((d) => d.data()['forumId'] as String?)
        .whereType<String>()
        .toList();
  }

  /// The forums among [ids] that exist, in one `documentId in [...]` query
  /// per 30 ids (Firestore's `in` cap) — a document-id lookup, so it needs no
  /// composite index. Ids with no forum doc yet are simply absent.
  Future<List<ForumEntity>> getForumsByIds(List<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const [];
    final chunks = [
      for (var i = 0; i < unique.length; i += 30)
        unique.sublist(i, i + 30 > unique.length ? unique.length : i + 30),
    ];
    final snaps = await Future.wait(chunks.map(
        (chunk) => _forums.where(FieldPath.documentId, whereIn: chunk).get()));
    return [
      for (final snap in snaps)
        for (final doc in snap.docs) ForumModel.fromFirestore(doc).toEntity(),
    ];
  }

  /// Forums the given user follows.
  Future<List<ForumEntity>> getFollowedForums(String userId) async {
    return getForumsByIds(await getFollowedForumIds(userId));
  }

  /// Creates a post in a forum and bumps its `postCount`.
  ///
  /// [postType], [authorBike] and [attachment] are the Pit Wall fields
  /// (post tag, byline bike badge, shared ride/maintenance card). A new post
  /// always starts unsolved; only [setPostSolution] moves that.
  Future<String> createPost({
    required String forumId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String title,
    required String body,
    ForumPostType postType = ForumPostType.general,
    String? authorBike,
    ForumAttachment? attachment,
  }) async {
    final postRef = _forums.doc(forumId).collection('posts').doc();

    // One atomic batch, and the bump names the new post in `lastPostId`, so
    // firestore.rules can require that `postCount` only moves when that post
    // is created by the caller in the same commit (issues §90.D11). Two
    // separate writes, as this used to do, also left the count short by one
    // whenever the second write failed.
    final batch = _firestore.batch();
    batch.set(postRef, {
      ...newForumPostFields(
        forumId: forumId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        title: title,
        body: body,
        postType: postType,
        authorBike: authorBike,
        attachment: attachment,
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_forums.doc(forumId), {
      'postCount': FieldValue.increment(1),
      'lastPostId': postRef.id,
    });
    await batch.commit();

    return postRef.id;
  }

  /// Sets a troubleshooting post's solved state (see `forum_solution.dart`
  /// for the toggles). firestore.rules lets only the post's author write
  /// these two fields, only on a `troubleshoot` post, and only with a
  /// [solutionReplyId] that names an existing reply of that post.
  Future<void> setPostSolution({
    required String forumId,
    required String postId,
    required bool isSolved,
    String? solutionReplyId,
  }) async {
    await _forums.doc(forumId).collection('posts').doc(postId).update({
      'isSolved': isSolved,
      'solutionReplyId': solutionReplyId,
    });
  }

  /// The forums whose posts make up [forumId]'s post list: itself, plus —
  /// for a [ForumType.brand] forum — every [ForumType.bikeModel] forum under
  /// that brand, so a post made in
  /// "Honda CB Shine 125" also shows up when viewing "Honda", tagged with
  /// its own model forum in the UI (`_PostCard`'s origin badge). This is a
  /// read-time merge, not a write-time copy: a merged post still lives only
  /// in its own model forum's `posts` subcollection, still counts only
  /// toward that forum's `postCount`, and voting/deleting it always targets
  /// its own [ForumPostEntity.forumId] — never the brand forum's id — which
  /// is why every post in the returned list is fully self-describing rather
  /// than assumed to belong to [forumId].
  ///
  /// Deliberately one-directional: a brand forum's own posts never appear
  /// inside a narrower model forum. `forum_providers.dart`'s
  /// `garageForumTargets` made the opposite call once already (owning a
  /// bike adds you to its model forum, not the noisier brand forum above
  /// it) for the same reason — mixing broad and narrow content the other
  /// way buries what a rider actually came to read. Merging model → brand
  /// doesn't have that problem: the brand forum is the broad one, so a
  /// specific post surfacing there is additive, not noise.
  ///
  /// Paged (issues §90.A8): this used to read EVERY post of the forum and of
  /// every merged model forum, plus one vote read per post, on every open.
  /// Now [postSourceForumIds] resolves which forums feed the list (once per
  /// list, not per page) and [getPostsPage] reads [limit] posts per source
  /// from a cursor, merging them without holes ([mergeForumPostPages]).
  Future<List<String>> postSourceForumIds(String forumId) async {
    final forumDoc = await _forums.doc(forumId).get();
    final forum = forumDoc.exists ? ForumModel.fromFirestore(forumDoc).toEntity() : null;
    if (forum == null || forum.type != ForumType.brand) return [forumId];
    final modelForums = await _modelForumsUnder(forum.brand);
    return [forumId, for (final f in modelForums) if (f.id != forumId) f.id];
  }

  /// One page of posts across [forumIds] (see [postSourceForumIds]), newest
  /// first, with the signed-in rider's votes hydrated for that page only.
  /// [before] is the previous page's [ForumPostsPage.cursor].
  Future<ForumPostsPage> getPostsPage(
    List<String> forumIds, {
    int limit = kForumPostsPageSize,
    DateTime? before,
  }) async {
    final perForum = await Future.wait(
        forumIds.map((id) => _postsIn(id, limit: limit, before: before)));
    final page = mergeForumPostPages(perForum, limit: limit);
    return ForumPostsPage(
      posts: await _hydrateVotes(page.posts),
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  Future<List<ForumPostEntity>> _postsIn(
    String forumId, {
    required int limit,
    DateTime? before,
  }) async {
    var q = _forums
        .doc(forumId)
        .collection('posts')
        .orderBy('createdAt', descending: true);
    if (before != null) q = q.startAfter([Timestamp.fromDate(before)]);
    final snapshot = await q.limit(limit).get();
    return snapshot.docs.map((doc) => ForumPostModel.fromFirestore(doc).toEntity()).toList();
  }

  /// The model forums whose posts merge into a brand forum — see the
  /// brand-merge notes on [postSourceForumIds].
  ///
  /// `brand`-equality is a plain single-field query, which Firestore always
  /// auto-indexes — deliberately not a compound `where('type', ...)
  /// .where('brand', ...)` query or a `collectionGroup('posts')` query.
  /// `modelForumsToMergeInto` does the `type`/`postCount` filtering
  /// client-side instead (same "fetch broader, filter in memory" shape as
  /// [searchForums] above). `cleanup_qa_test_riders.js`
  /// (`scripts/qa_seed_catalog.js`) hit exactly this the hard way: a
  /// `collectionGroup('posts').where('qaSeed', '==', true)` query failed
  /// outright with `FAILED_PRECONDITION` because this project has no
  /// composite index for it — not worth risking here too.
  Future<List<ForumEntity>> _modelForumsUnder(String brand) async {
    if (brand.trim().isEmpty) return const [];
    final candidatesSnap = await _forums.where('brand', isEqualTo: brand).get();
    final candidates =
        candidatesSnap.docs.map((doc) => ForumModel.fromFirestore(doc).toEntity()).toList();
    return modelForumsToMergeInto(brand, candidates);
  }

  Future<ForumPostEntity?> getPost({
    required String forumId,
    required String postId,
  }) async {
    final doc = await _forums.doc(forumId).collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    final post = ForumPostModel.fromFirestore(doc).toEntity();
    final hydrated = await _hydrateVotes([post]);
    return hydrated.first;
  }

  /// Hydrates the signed-in rider's vote state onto each post — entity-only,
  /// never stored on the post doc itself (mirrors
  /// RideShareRepository._hydrate's myVote pattern).
  ///
  /// Reads each vote from the post's OWN `forumId`, not a shared one for the
  /// whole list — required since [getPosts] can now return posts merged in
  /// from several different model forums at once.
  Future<List<ForumPostEntity>> _hydrateVotes(List<ForumPostEntity> posts) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || posts.isEmpty) return posts;

    final votes =
        await Future.wait(posts.map((p) => getMyPostVote(p.forumId, p.id, uid)));
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

    // One transaction, and the bump carries the new reply's id, so
    // firestore.rules can tie the `replyCount` +1 to a reply doc actually
    // being created in the same commit (issues §24.7). Mirrors
    // RideShareRepository.addComment().
    await _firestore.runTransaction((transaction) async {
      transaction.set(replyRef, {
        'postId': postId,
        'forumId': forumId,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {
        'replyCount': FieldValue.increment(1),
        'lastReplyId': replyRef.id,
      });
    });

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
