import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/num_cast.dart';
import '../../domain/bike_visibility.dart';
import '../../domain/entities/user_profile_entity.dart';

/// Firestore (de)serializer for a `users/{uid}` public profile document.
///
/// Only the profile fields live at the document root; the owner-only
/// subcollections (rides/bikes/maintenance/...) are untouched by this model.
class UserProfileModel {
  static UserProfileEntity fromFirestore(
      Map<String, dynamic> data, String uid) {
    // The public rider list parses every public profile, and each is written
    // by its own rider, so a wrong-typed field falls back instead of throwing.
    final stats = asOrNull<Map>(data['publicStats']);
    num? stat(String key) => asOrNull<num>(stats?[key]);
    return UserProfileEntity(
      uid: uid,
      displayName: asOrNull<String>(data['displayName']) ?? '',
      username: asOrNull<String>(data['username']),
      nickname: asOrNull<String>(data['nickname']),
      bio: asOrNull<String>(data['bio']),
      photoUrl: asOrNull<String>(data['photoUrl']),
      email: asOrNull<String>(data['email']),
      followerCount: asOrNull<num>(data['followerCount'])?.toInt() ?? 0,
      followingCount: asOrNull<num>(data['followingCount'])?.toInt() ?? 0,
      ownedPlaceIds:
          asOrNull<List>(data['ownedPlaceIds'])?.whereType<String>().toList() ??
              const [],
      visibility: asOrNull<String>(data['visibility']) ?? 'public',
      // Absent on every account created before the garage-visibility setting
      // shipped — those must keep behaving exactly as they did, i.e. public.
      bikesVisibility:
          asOrNull<String>(data['bikesVisibility']) ?? kBikesVisibilityPublic,
      totalDistanceKm: stat('totalDistanceKm')?.toDouble() ?? 0,
      totalRides: stat('totalRides')?.toInt() ?? 0,
      badgeIds:
          asOrNull<List>(stats?['badgeIds'])?.whereType<String>().toList() ??
              const [],
      longestRideKm: stat('longestRideKm')?.toDouble() ?? 0,
      longestDayStreak: stat('longestDayStreak')?.toInt() ?? 0,
      pinnedRideIds:
          asOrNull<List>(data['pinnedRideIds'])?.whereType<String>().toList() ??
              const [],
      createdAt: asOrNull<Timestamp>(data['createdAt'])?.toDate(),
      updatedAt: asOrNull<Timestamp>(data['updatedAt'])?.toDate(),
    );
  }

  /// The subset of fields written on profile edit. `usernameLower` is a
  /// denormalized copy used purely for case-insensitive search queries.
  static Map<String, dynamic> editableFields({
    String? displayName,
    String? username,
    String? nickname,
    String? bio,
    String? photoUrl,
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
