import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../data/repositories/follow_repository.dart';

final followRepositoryProvider =
    Provider<FollowRepository>((ref) => FollowRepository());

/// Uids the signed-in rider follows (drives the "following" feed + audience
/// filtering). Empty when signed out.
final followingIdsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(followRepositoryProvider).getFollowing(user.uid);
});

/// Uids the signed-in rider mutually follows (friends).
final mutualIdsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(followRepositoryProvider).getMutuals(user.uid);
});

/// Whether the signed-in rider follows [uid] (live).
final isFollowingProvider = StreamProvider.family<bool, String>((ref, uid) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsFollowing(user.uid, uid);
});

final followerCountProvider = FutureProvider.family<int, String>((ref, uid) {
  return ref.watch(followRepositoryProvider).followerCount(uid);
});

final followingCountProvider = FutureProvider.family<int, String>((ref, uid) {
  return ref.watch(followRepositoryProvider).followingCount(uid);
});

/// Suggestions: mutuals first (followers you don't follow back), then recent users
final suggestedProfilesProvider = FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  
  final followRepo = ref.watch(followRepositoryProvider);
  final followers = await followRepo.getFollowers(user.uid);
  final following = await followRepo.getFollowing(user.uid);
  
  final notFollowedBack = followers.where((id) => !following.contains(id) && id != user.uid).toList();
  
  // ignore: prefer_collection_literals
  final suggestions = <UserProfileEntity>[];
  final profileRepo = ProfileRepository();
  
  if (notFollowedBack.isNotEmpty) {
    final notFollowedBackProfiles = await Future.wait(notFollowedBack.map(profileRepo.getProfile));
    suggestions.addAll(notFollowedBackProfiles.whereType<UserProfileEntity>());
  }
  
  if (suggestions.length < 10) {
    final recentUsers = await profileRepo.getRecentUsers(limit: 50);
    for (final u in recentUsers) {
      if (u.uid != user.uid && !following.contains(u.uid) && !suggestions.any((s) => s.uid == u.uid)) {
        suggestions.add(u);
      }
    }
  }
  
  return suggestions;
});
