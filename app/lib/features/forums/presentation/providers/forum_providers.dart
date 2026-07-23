import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/slugify.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_entity.dart';
import '../../domain/entities/forum_post_entity.dart';

final _forumRepository = ForumRepository();

/// One forum per unique bike (by brand+model) in the current user's garage,
/// created on demand via `getOrCreateForum` so "Your bikes" forums always
/// exist without any separate seeding step. Deduped by slug so two bikes of
/// the same brand+model don't resolve the same forum twice.
final forumsForGarageProvider = FutureProvider<List<ForumEntity>>((ref) async {
  final bikes = ref.watch(garageProvider).valueOrNull ?? [];
  final seenSlugs = <String>{};
  final forums = <ForumEntity>[];

  for (final bike in bikes) {
    final slug = bikeForumSlug(bike.brand, model: bike.model);
    if (!seenSlugs.add(slug)) continue;
    forums.add(await _forumRepository.getOrCreateForum(brand: bike.brand, model: bike.model));
  }

  return forums;
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
  return ForumPostsNotifier(ref, forumId, posts);
});

class ForumPostsNotifier extends StateNotifier<List<ForumPostEntity>> {
  ForumPostsNotifier(this._ref, this._forumId, List<ForumPostEntity> initial) : super(initial);

  final Ref _ref;
  final String _forumId;
  final _repo = ForumRepository();

  /// Casts/changes/clears a vote (1 upvote, -1 downvote). Tapping the same
  /// arrow again clears it, mirroring RideFeedNotifier.vote.
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
      await _repo.votePost(_forumId, postId, uid, value);
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
}

/// Whether the current user follows the given forum. False (not an error)
/// when signed out.
final forumFollowingProvider = FutureProvider.family<bool, String>((ref, forumId) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return false;
  return _forumRepository.isFollowing(forumId, uid);
});
