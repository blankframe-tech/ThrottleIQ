import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile_entity.dart';

/// Firestore (de)serializer for a `users/{uid}` public profile document.
///
/// Only the profile fields live at the document root; the owner-only
/// subcollections (rides/bikes/maintenance/...) are untouched by this model.
class UserProfileModel {
  static UserProfileEntity fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfileEntity(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '',
      username: data['username'] as String?,
      nickname: data['nickname'] as String?,
      bio: data['bio'] as String?,
      photoUrl: data['photoUrl'] as String?,
      email: data['email'] as String?,
      followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      ownedPlaceIds:
          (data['ownedPlaceIds'] as List?)?.whereType<String>().toList() ??
              const [],
      visibility: (data['visibility'] as String?) ?? 'public',
      totalDistanceKm:
          ((data['publicStats'] as Map?)?['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      totalRides: ((data['publicStats'] as Map?)?['totalRides'] as num?)?.toInt() ?? 0,
      badgeIds: ((data['publicStats'] as Map?)?['badgeIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The subset of fields written on profile edit. `usernameLower`/`emailLower`
  /// are denormalized copies used purely for case-insensitive search queries.
  static Map<String, dynamic> editableFields({
    String? displayName,
    String? username,
    String? nickname,
    String? bio,
    String? photoUrl,
    String? email,
  }) {
    return {
      if (displayName != null) 'displayName': displayName,
      if (username != null) ...{
        'username': username,
        'usernameLower': username.toLowerCase(),
      },
      if (nickname != null) 'nickname': nickname,
      if (bio != null) 'bio': bio,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (email != null) ...{
        'email': email,
        'emailLower': email.toLowerCase(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
