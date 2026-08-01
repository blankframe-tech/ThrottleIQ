import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/domain/entities/bike_entity.dart';
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

/// Another rider's synced garage, for the bikes section on their profile.
///
/// Only ever watched once [canSeeBikes] has cleared the viewer, and gated
/// again by firestore.rules — a viewer the rules refuse gets an AsyncError
/// here, which the profile screen renders as "no garage section". The
/// signed-in rider's own garage never comes through this provider; that's
/// garageProvider (local DB), which is authoritative and always available.
final riderBikesProvider =
    FutureProvider.family<List<BikeEntity>, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).getBikesFor(uid);
});
