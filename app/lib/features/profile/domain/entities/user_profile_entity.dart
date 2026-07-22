import 'package:equatable/equatable.dart';

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
    final source = bestName.replaceFirst('@', '').trim();
    if (source.isEmpty) return 'R';
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
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
        createdAt,
        updatedAt,
      ];
}
