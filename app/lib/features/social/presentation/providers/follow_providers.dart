import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
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
