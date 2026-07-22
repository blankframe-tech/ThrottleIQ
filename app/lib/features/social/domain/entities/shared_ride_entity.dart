import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

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

  /// A rider-taken photo of the ride/bike (distinct from [mapSnapshotUrl],
  /// which is a rendered map trace).
  final String? photoUrl;

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
    this.photoUrl,
    this.upvotes = 0,
    this.downvotes = 0,
    this.myVote,
  });

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
    String? photoUrl,
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
      photoUrl: photoUrl ?? this.photoUrl,
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
      ];
}
