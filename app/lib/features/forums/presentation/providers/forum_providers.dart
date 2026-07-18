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

/// Whether the current user follows the given forum. False (not an error)
/// when signed out.
final forumFollowingProvider = FutureProvider.family<bool, String>((ref, forumId) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return false;
  return _forumRepository.isFollowing(forumId, uid);
});
