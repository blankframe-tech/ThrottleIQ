import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/slugify.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_entity.dart';
import '../../domain/entities/forum_post_entity.dart';

final _forumRepository = ForumRepository();

/// SharedPreferences keys for the "Your bikes" forum cache. See
/// [forumsForGarageProvider] for why this cache exists at all.
const String kGarageForumsCacheKey = 'forums_for_garage_cache';
const String kGarageForumsSignatureKey = 'forums_for_garage_signature';

/// Deterministic fingerprint of the forums the current garage implies.
///
/// Pure so it can be unit-tested without Firestore or SharedPreferences.
/// Each bike contributes exactly one slug — its brand+model forum — deduped
/// and sorted, so the signature depends only on the *set* of forums the
/// garage needs, not on bike ids, ordering, mileage, or any other field that
/// changes constantly. That's the whole point: re-ordering the garage or
/// logging a ride must not invalidate the cache, but adding a genuinely new
/// bike must.
///
/// Bikes with no model recorded contribute nothing: `bikeForumSlug(brand)`
/// with an empty model is just the brand forum, which is precisely what
/// "Your bikes" is no longer meant to include. Such a bike shows no forum
/// here until it's given a model — the brand forum is still one search away
/// under "Find a forum".
String garageForumsSignature(List<BikeEntity> bikes) {
  final sorted = garageForumTargets(bikes).map((t) => t.slug).toList()..sort();
  return sorted.join(',');
}

/// The forums a garage implies: one per distinct bike model, and **not** the
/// brand forums above them.
///
/// Owning a Yamaha RXS 1154 says you want to talk about the RXS 1154. It does
/// not say you want every thread about every Yamaha ever made auto-added to
/// your bikes — which is what the previous brand+model pair did, and which
/// buried the forum a rider actually cared about under a much noisier one
/// they never asked for. Brand forums still exist and are still followable;
/// they're just opt-in via discovery now rather than assigned by ownership.
List<({String slug, String brand, String model})> garageForumTargets(
    List<BikeEntity> bikes) {
  final seen = <String>{};
  final targets = <({String slug, String brand, String model})>[];
  for (final bike in bikes) {
    if (bike.model.trim().isEmpty) continue;
    final slug = bikeForumSlug(bike.brand, model: bike.model);
    if (slug.isEmpty || !seen.add(slug)) continue;
    targets.add((slug: slug, brand: bike.brand, model: bike.model));
  }
  return targets;
}

/// Serializes a resolved forum for the SharedPreferences cache. Only the
/// fields the "Your bikes" list actually renders are stored — notably not
/// `createdAt`, which nothing in that list displays and which would only
/// add a timestamp-format footgun to the cache.
Map<String, dynamic> _encodeCachedForum(ForumEntity forum) => {
      'slug': forum.id,
      'displayName': forum.displayName,
      'type': forum.type.name,
      'brand': forum.brand,
      'model': forum.model,
      'postCount': forum.postCount,
      'followerCount': forum.followerCount,
    };

/// Inverse of [_encodeCachedForum]. Returns an empty list on anything
/// malformed (hand-edited prefs, a format change across an app update) so a
/// bad cache degrades to "resolve from Firestore" rather than crashing the
/// forums tab.
List<ForumEntity> decodeCachedGarageForums(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map<String, dynamic> && entry['slug'] is String)
          ForumEntity(
            id: entry['slug'] as String,
            type: ForumType.fromString(entry['type'] as String? ?? 'brand'),
            brand: entry['brand'] as String? ?? '',
            model: entry['model'] as String?,
            displayName: entry['displayName'] as String? ?? '',
            postCount: (entry['postCount'] as num?)?.toInt() ?? 0,
            followerCount: (entry['followerCount'] as num?)?.toInt() ?? 0,
            // Not cached — see _encodeCachedForum.
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
    ];
  } catch (_) {
    return const [];
  }
}

/// One forum per unique bike in the current rider's garage — the specific
/// model forum ("Yamaha RX100"), never the brand above it (see
/// [garageForumTargets]) — created on demand via `getOrCreateForum` so "Your
/// bikes" forums always exist without any separate seeding step. Deduped by
/// slug, so two identical bikes share one forum.
///
/// Cached in SharedPreferences: this used to run one Firestore
/// `runTransaction` **per bike, on every rebuild and every visit to the
/// Forums tab** — reported as "in forums, my bikes section loads everytime".
/// The forums it resolves are deterministic functions of the garage (the
/// slug is derived from brand+model), so once resolved there is nothing new
/// to learn until the garage itself changes. [garageForumsSignature]
/// captures exactly that, and a matching signature short-circuits to the
/// cached list with **zero** Firestore reads. On a mismatch only the slugs
/// that aren't already cached are resolved — adding one bike costs one or
/// two transactions, not one per bike in the garage.
final forumsForGarageProvider = FutureProvider<List<ForumEntity>>((ref) async {
  final bikes = ref.watch(garageProvider).valueOrNull ?? [];
  final signature = garageForumsSignature(bikes);

  final prefs = await SharedPreferences.getInstance();
  final cachedSignature = prefs.getString(kGarageForumsSignatureKey);
  final cached = decodeCachedGarageForums(prefs.getString(kGarageForumsCacheKey));

  if (cachedSignature == signature && (cached.isNotEmpty || bikes.isEmpty)) {
    return cached;
  }

  // Reuse anything already resolved; only genuinely new slugs hit Firestore.
  final cachedBySlug = {for (final forum in cached) forum.id: forum};
  final resolved = <ForumEntity>[];

  for (final target in garageForumTargets(bikes)) {
    final hit = cachedBySlug[target.slug];
    if (hit != null) {
      resolved.add(hit);
      continue;
    }
    resolved.add(await _forumRepository.getOrCreateForum(
      brand: target.brand,
      model: target.model,
    ));
  }

  await prefs.setString(
    kGarageForumsCacheKey,
    jsonEncode(resolved.map(_encodeCachedForum).toList()),
  );
  await prefs.setString(kGarageForumsSignatureKey, signature);

  return resolved;
});

/// Drops the cached signature so the next [forumsForGarageProvider] read
/// re-resolves from Firestore. The forum list itself is left in place — it
/// is still a valid set of already-resolved slugs to reuse, so a forced
/// refresh still doesn't re-transact for bikes that haven't changed.
Future<void> clearGarageForumsCacheSignature() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kGarageForumsSignatureKey);
}

/// Forces "Your bikes" to re-resolve — call after anything that changes a
/// forum's stored counters (follow/unfollow, a new post). A plain
/// `ref.invalidate(forumsForGarageProvider)` still works but would just
/// re-serve the cache, since the garage signature hasn't changed.
Future<void> refreshGarageForums(WidgetRef ref) async {
  await clearGarageForumsCacheSignature();
  ref.invalidate(forumsForGarageProvider);
}

/// Rider-created forums, newest first — the "Rider forums" discovery list
/// on the forums home screen.
final customForumsProvider = FutureProvider<List<ForumEntity>>((ref) {
  return _forumRepository.getCustomForums();
});

/// A single forum's metadata by id, for screens that only have the slug
/// (e.g. arriving via a route parameter).
final forumByIdProvider = FutureProvider.family<ForumEntity?, String>((ref, forumId) {
  return _forumRepository.getForum(forumId);
});

final forumPostsProvider = FutureProvider.family<List<ForumPostEntity>, String>((ref, forumId) {
  return _forumRepository.getPosts(forumId);
});

/// Holds a forum's post list locally so votes can be toggled optimistically
/// without waiting on a Firestore round-trip. Seeded from
/// [forumPostsProvider] once it resolves — mirrors RideFeedNotifier.
final forumPostsNotifierProvider = StateNotifierProvider.family<ForumPostsNotifier,
    List<ForumPostEntity>, String>((ref, forumId) {
  final posts = ref.watch(forumPostsProvider(forumId)).valueOrNull ?? [];
  return ForumPostsNotifier(ref, posts);
});

class ForumPostsNotifier extends StateNotifier<List<ForumPostEntity>> {
  ForumPostsNotifier(this._ref, List<ForumPostEntity> initial) : super(initial);

  final Ref _ref;
  final _repo = ForumRepository();

  /// Casts/changes/clears a vote (1 upvote, -1 downvote). Tapping the same
  /// arrow again clears it, mirroring RideFeedNotifier.vote.
  ///
  /// Always writes to the post's OWN `forumId`, not the screen's — this list
  /// can include posts merged in from a bike-model forum while viewing that
  /// bike's brand forum (see ForumRepository.getPosts), and voting on one of
  /// those has to land in the model forum it actually lives in.
  Future<void> vote(String postId, int value) async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final post = state.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;

    final clearing = post.myVote == value;
    final newVote = clearing ? null : value;
    var newUpvotes = post.upvotes;
    var newDownvotes = post.downvotes;
    if (post.myVote == 1) newUpvotes--;
    if (post.myVote == -1) newDownvotes--;
    if (newVote == 1) newUpvotes++;
    if (newVote == -1) newDownvotes++;

    state = [
      for (final p in state)
        if (p.id == postId)
          p.copyWith(myVote: newVote, upvotes: newUpvotes, downvotes: newDownvotes)
        else
          p,
    ];

    try {
      await _repo.votePost(post.forumId, postId, uid, value);
    } catch (e) {
      state = [
        for (final p in state)
          if (p.id == postId) post else p,
      ];
      // Previously swallowed: the optimistic vote would flash then quietly
      // revert with no feedback at all — reported as "votes are lost" since
      // there was nothing distinguishing a silent failure from success.
      // Rethrowing lets the UI show the rider what actually happened.
      rethrow;
    }
  }

  /// Patches the cached reply count after a successful post, mirroring
  /// RideFeedNotifier.incrementCommentCount.
  void incrementReplyCount(String postId) {
    state = [
      for (final p in state)
        if (p.id == postId) p.copyWith(replyCount: p.replyCount + 1) else p,
    ];
  }

  /// Drops a deleted post from the local list so the thread updates without
  /// waiting on a full [forumPostsProvider] refetch.
  void removePost(String postId) {
    state = [
      for (final p in state)
        if (p.id != postId) p,
    ];
  }
}

/// Whether the current user follows the given forum. False (not an error)
/// when signed out.
final forumFollowingProvider = FutureProvider.family<bool, String>((ref, forumId) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return false;
  return _forumRepository.isFollowing(forumId, uid);
});
