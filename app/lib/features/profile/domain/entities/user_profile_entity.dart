import 'package:equatable/equatable.dart';

import '../../../../core/utils/initials.dart';
import '../bike_visibility.dart';

/// A rider's public-facing profile.
///
/// Stored at Firestore `users/{uid}` (the same doc that already holds the
/// owner-only ride/bike/maintenance subcollections). The *document fields*
/// here are made publicly readable (any authenticated user) so riders can be
/// found by username/email and followed — the subcollections stay owner-only
/// (see firestore.rules).
class UserProfileEntity extends Equatable {
  final String uid;

  /// The rider's real name (mirrors FirebaseAuth displayName). May be empty
  /// for legacy accounts created before onboarding captured it.
  final String displayName;

  /// Unique @handle used for search + mentions. Lowercased, `[a-z0-9_]`.
  /// Nullable until the rider picks one.
  final String? username;

  /// Freeform display nickname shown on cards/feed (falls back to
  /// displayName, then "Rider").
  final String? nickname;

  final String? bio;

  /// Avatar URL (Firebase Storage). Null → render a default/initial avatar.
  final String? photoUrl;

  /// Lowercased email, stored only to support exact-match "find by email".
  final String? email;

  final int followerCount;
  final int followingCount;

  /// Place ids this rider owns/manages (see PlaceEntity.ownerId). Surfaced on
  /// the profile as "My places".
  final List<String> ownedPlaceIds;

  /// Who can view this profile doc (and its [publicStats]): 'public' (any
  /// signed-in rider — the default, matching pre-existing behavior before
  /// this field existed), 'mutual' (only riders who follow each other), or
  /// 'private' (owner only). Enforced by firestore.rules.
  final String visibility;

  /// Who can see this rider's garage: 'public' (any signed-in rider — the
  /// default, and what a doc written before this field existed decodes to),
  /// 'followers' (only riders who follow them), or 'private' (owner only).
  /// Separate from [visibility] because a rider can want a findable profile
  /// but a closed garage. See `domain/bike_visibility.dart` for the predicate
  /// and firestore.rules for enforcement.
  final String bikesVisibility;

  /// Denormalized ride stats, written by the owner's own device on ride
  /// finalize (see ProfileRepository.updatePublicStats) — kept off the
  /// owner-only `rides`/`bikes` subcollections so a public/mutual profile
  /// view can show them without those subcollections needing to open up to
  /// cross-user reads.
  final double totalDistanceKm;
  final int totalRides;
  final List<String> badgeIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfileEntity({
    required this.uid,
    this.displayName = '',
    this.username,
    this.nickname,
    this.bio,
    this.photoUrl,
    this.email,
    this.followerCount = 0,
    this.followingCount = 0,
    this.ownedPlaceIds = const [],
    this.visibility = 'public',
    this.bikesVisibility = kBikesVisibilityPublic,
    this.totalDistanceKm = 0,
    this.totalRides = 0,
    this.badgeIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// The best human label for this rider: nickname → displayName → @username
  /// → "Rider".
  String get bestName {
    if (nickname != null && nickname!.trim().isNotEmpty) return nickname!.trim();
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Rider';
  }

  /// Uppercase initials for the fallback avatar (GitHub-style).
  String get initials {
    return initialsFrom(bestName);
  }

  UserProfileEntity copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? nickname,
    String? bio,
    String? photoUrl,
    String? email,
    int? followerCount,
    int? followingCount,
    List<String>? ownedPlaceIds,
    String? visibility,
    String? bikesVisibility,
    double? totalDistanceKm,
    int? totalRides,
    List<String>? badgeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      ownedPlaceIds: ownedPlaceIds ?? this.ownedPlaceIds,
      visibility: visibility ?? this.visibility,
      bikesVisibility: bikesVisibility ?? this.bikesVisibility,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalRides: totalRides ?? this.totalRides,
      badgeIds: badgeIds ?? this.badgeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        displayName,
        username,
        nickname,
        bio,
        photoUrl,
        email,
        followerCount,
        followingCount,
        ownedPlaceIds,
        visibility,
        bikesVisibility,
        totalDistanceKm,
        totalRides,
        badgeIds,
        createdAt,
        updatedAt,
      ];
}
