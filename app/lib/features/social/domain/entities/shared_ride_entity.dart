import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// How many rider-taken photos one shared ride may carry.
///
/// The feed card shows the photos beside the route map (each gets half the
/// card width), so this is a product cap rather than a storage one — past
/// three, a rider is posting an album, not a ride.
const int kMaxRidePhotos = 3;

/// Cleans a raw photo-url list into the shape [SharedRideEntity.photoUrls]
/// guarantees: no nulls, no blanks, no duplicates, at most [kMaxRidePhotos],
/// order preserved.
///
/// [legacyPhotoUrl] is the pre-multi-photo single `photoUrl` field. It is used
/// ONLY when [urls] yields nothing, so a ride shared before this change still
/// renders its one photo, while a ride written by the new code (which mirrors
/// its first photo back into `photoUrl` for older app builds) never counts the
/// same image twice.
///
/// Pure and Flutter-free so both the model's read path and the share composer
/// can enforce the cap identically — see
/// `test/features/social/shared_ride_entity_test.dart`.
List<String> normalizeRidePhotoUrls(
  Iterable<String?>? urls, {
  String? legacyPhotoUrl,
}) {
  final out = <String>[];
  for (final url in urls ?? const <String?>[]) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty || out.contains(trimmed)) continue;
    out.add(trimmed);
    if (out.length == kMaxRidePhotos) break;
  }
  if (out.isEmpty) {
    final legacy = legacyPhotoUrl?.trim() ?? '';
    if (legacy.isNotEmpty) out.add(legacy);
  }
  return out;
}

class SharedRideEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String bikeId;
  final String bikeName;
  final String bikeType;
  final DateTime rideDate;
  final double distanceKm;
  final int durationSeconds;
  final double maxSpeedKmh;
  final List<LatLng> polyline;
  final String? mapSnapshotUrl;
  final int likes;
  final int comments;
  final bool isLikedByCurrentUser;
  final DateTime createdAt;

  /// Who can see this ride: `public` / `followers` / `mutual`. Followers/
  /// mutual visibility is materialized into [allowedUserIds] at share time
  /// (see RideShareRepository.shareRide) since Firestore rules can't run a
  /// per-doc follow-graph lookup for a list query.
  final String audience;
  final List<String> allowedUserIds;
  final String? routeId; // Optional reference to saved route

  /// Rider-taken photos of the ride/bike (distinct from [mapSnapshotUrl],
  /// which is a rendered map trace), newest-first as the rider ordered them.
  /// At most [kMaxRidePhotos]; empty when the ride has no photo.
  ///
  /// Rides shared before multi-photo support carry a single `photoUrl` string
  /// in Firestore instead; [RideShareModel.fromFirestore] folds that into this
  /// list, so nothing downstream has to know which era a ride came from.
  final List<String> photoUrls;

  /// Optional rider-written blurb shown above the media on the feed card.
  /// Absent on rides shared before captions existed, hence nullable.
  final String? caption;

  final int upvotes;
  final int downvotes;

  /// The signed-in rider's own vote on this ride: 1, -1, or null (none).
  /// Entity-only — hydrated from the `votes/{uid}` subcollection at read
  /// time, never stored on the ride doc itself (mirrors
  /// [isLikedByCurrentUser]).
  final int? myVote;

  const SharedRideEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.bikeId,
    required this.bikeName,
    required this.bikeType,
    required this.rideDate,
    required this.distanceKm,
    required this.durationSeconds,
    required this.maxSpeedKmh,
    required this.polyline,
    this.mapSnapshotUrl,
    this.likes = 0,
    this.comments = 0,
    this.isLikedByCurrentUser = false,
    required this.createdAt,
    this.audience = 'public',
    this.allowedUserIds = const [],
    this.routeId,
    this.photoUrls = const [],
    this.caption,
    this.upvotes = 0,
    this.downvotes = 0,
    this.myVote,
  });

  /// The ride's lead photo — the first of [photoUrls], or null when it has
  /// none. Kept as the single-photo accessor so callers that only ever want
  /// one image (and the legacy `photoUrl` Firestore field written for older
  /// app builds) have one obvious source.
  String? get photoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  int get durationMinutes => durationSeconds ~/ 60;
  double get avgSpeedKmh =>
      durationSeconds > 0 ? (distanceKm / durationSeconds) * 3600 : 0;
  int get netScore => upvotes - downvotes;

  /// Sentinel so [copyWith] can distinguish "leave myVote alone" from
  /// "set myVote to null" (clearing a vote) — a plain `int? myVote` param
  /// can't tell those apart since both look like `null`.
  static const _unset = Object();

  SharedRideEntity copyWith({
    int? likes,
    int? comments,
    bool? isLikedByCurrentUser,
    String? audience,
    List<String>? allowedUserIds,
    List<String>? photoUrls,
    String? caption,
    int? upvotes,
    int? downvotes,
    Object? myVote = _unset,
  }) {
    return SharedRideEntity(
      id: id,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      bikeId: bikeId,
      bikeName: bikeName,
      bikeType: bikeType,
      rideDate: rideDate,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      maxSpeedKmh: maxSpeedKmh,
      polyline: polyline,
      mapSnapshotUrl: mapSnapshotUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      createdAt: createdAt,
      audience: audience ?? this.audience,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      routeId: routeId,
      photoUrls: photoUrls ?? this.photoUrls,
      caption: caption ?? this.caption,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      myVote: identical(myVote, _unset) ? this.myVote : myVote as int?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        rideDate,
        createdAt,
        isLikedByCurrentUser,
        upvotes,
        downvotes,
        myVote,
        caption,
        photoUrls,
      ];
}
