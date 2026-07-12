import 'package:latlong2/latlong.dart';

import '../../domain/entities/shared_ride_entity.dart';

class RideShareModel {
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
  final List<String> allowedUserIds;
  final String? routeId;

  RideShareModel({
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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'bikeId': bikeId,
      'bikeName': bikeName,
      'bikeType': bikeType,
      'rideDate': rideDate,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'maxSpeedKmh': maxSpeedKmh,
      'polyline': polyline
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'mapSnapshotUrl': mapSnapshotUrl,
      'likes': likes,
      'comments': comments,
      'createdAt': createdAt,
      'isPrivate': isPrivate,
      'allowedUserIds': allowedUserIds,
      'routeId': routeId,
    };
  }

  factory RideShareModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    final polylineList = (data['polyline'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(
              (point) => LatLng(
                point['lat'] as double,
                point['lng'] as double,
              ),
            )
            .toList() ??
        [];

    return RideShareModel(
      id: docId,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      userPhotoUrl: data['userPhotoUrl'] as String,
      bikeId: data['bikeId'] as String,
      bikeName: data['bikeName'] as String,
      bikeType: data['bikeType'] as String,
      rideDate: (data['rideDate'] as dynamic).toDate() ?? DateTime.now(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      maxSpeedKmh: (data['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
      polyline: polylineList,
      mapSnapshotUrl: data['mapSnapshotUrl'] as String?,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      comments: (data['comments'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as dynamic).toDate() ?? DateTime.now(),
      isPrivate: data['isPrivate'] as bool? ?? false,
      allowedUserIds:
          (data['allowedUserIds'] as List<dynamic>?)?.cast<String>() ?? [],
      routeId: data['routeId'] as String?,
    );
  }

  SharedRideEntity toEntity() {
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
      likes: likes,
      comments: comments,
      isLikedByCurrentUser: isLikedByCurrentUser,
      createdAt: createdAt,
      isPrivate: isPrivate,
      allowedUserIds: allowedUserIds,
      routeId: routeId,
    );
  }
}
