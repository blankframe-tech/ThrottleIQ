import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/user_profile_entity.dart';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());

/// Live profile for an arbitrary uid.
final profileProvider =
    StreamProvider.family<UserProfileEntity?, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).watchProfile(uid);
});

/// Live profile for the signed-in rider (null while signed out).
final myProfileProvider = StreamProvider<UserProfileEntity?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(user.uid);
});
