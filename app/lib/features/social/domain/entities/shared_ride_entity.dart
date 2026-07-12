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
  final bool isPrivate;
  final List<String> allowedUserIds; // Empty = public
  final String? routeId; // Optional reference to saved route

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
    this.isPrivate = false,
    this.allowedUserIds = const [],
    this.routeId,
  });

  int get durationMinutes => durationSeconds ~/ 60;
  double get avgSpeedKmh =>
      durationSeconds > 0 ? (distanceKm / durationSeconds) * 3600 : 0;

  SharedRideEntity copyWith({
    int? likes,
    int? comments,
    bool? isLikedByCurrentUser,
    bool? isPrivate,
    List<String>? allowedUserIds,
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
      isPrivate: isPrivate ?? this.isPrivate,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      routeId: routeId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        rideDate,
        createdAt,
        isLikedByCurrentUser,
      ];
}
