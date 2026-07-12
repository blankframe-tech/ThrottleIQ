import 'package:latlong2/latlong.dart';

import '../../domain/entities/group_ride_entity.dart';

class GroupRideMemberModel {
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final DateTime joinedAt;
  final String status;
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationUpdate;

  GroupRideMemberModel({
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.joinedAt,
    this.status = 'joined',
    this.currentLat,
    this.currentLng,
    this.lastLocationUpdate,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'joinedAt': joinedAt,
      'status': status,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'lastLocationUpdate': lastLocationUpdate,
    };
  }

  factory GroupRideMemberModel.fromFirestore(Map<String, dynamic> data) {
    return GroupRideMemberModel(
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      userPhotoUrl: data['userPhotoUrl'] as String,
      joinedAt: (data['joinedAt'] as dynamic).toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'joined',
      currentLat: (data['currentLat'] as num?)?.toDouble(),
      currentLng: (data['currentLng'] as num?)?.toDouble(),
      lastLocationUpdate: data['lastLocationUpdate'] != null
          ? (data['lastLocationUpdate'] as dynamic).toDate()
          : null,
    );
  }

  GroupRideMember toEntity() {
    return GroupRideMember(
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      joinedAt: joinedAt,
      status: status == 'joined'
          ? GroupRideMemberStatus.joined
          : status == 'declined'
              ? GroupRideMemberStatus.declined
              : GroupRideMemberStatus.pending,
      currentLat: currentLat,
      currentLng: currentLng,
      lastLocationUpdate: lastLocationUpdate,
    );
  }
}

class GroupRideModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String name;
  final String? description;
  final DateTime startTime;
  final String? routeId;
  final List<LatLng>? routePolyline;
  final String status;
  final List<GroupRideMemberModel> members;
  final DateTime createdAt;
  final int maxParticipants;

  GroupRideModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.name,
    this.description,
    required this.startTime,
    this.routeId,
    this.routePolyline,
    this.status = 'planned',
    this.members = const [],
    required this.createdAt,
    this.maxParticipants = 20,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'name': name,
      'description': description,
      'startTime': startTime,
      'routeId': routeId,
      'routePolyline': routePolyline
          ?.map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'status': status,
      'members': members.map((m) => m.toFirestore()).toList(),
      'createdAt': createdAt,
      'maxParticipants': maxParticipants,
    };
  }

  factory GroupRideModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    final polylineList = (data['routePolyline'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(
              (point) => LatLng(
                point['lat'] as double,
                point['lng'] as double,
              ),
            )
            .toList() ??
        [];

    final membersList = (data['members'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map((m) => GroupRideMemberModel.fromFirestore(m))
            .toList() ??
        [];

    return GroupRideModel(
      id: docId,
      creatorId: data['creatorId'] as String,
      creatorName: data['creatorName'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      startTime: (data['startTime'] as dynamic).toDate() ?? DateTime.now(),
      routeId: data['routeId'] as String?,
      routePolyline: polylineList.isEmpty ? null : polylineList,
      status: data['status'] as String? ?? 'planned',
      members: membersList,
      createdAt: (data['createdAt'] as dynamic).toDate() ?? DateTime.now(),
      maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 20,
    );
  }

  GroupRideEntity toEntity() {
    return GroupRideEntity(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      name: name,
      description: description,
      startTime: startTime,
      routeId: routeId,
      routePolyline: routePolyline,
      status: status == 'active'
          ? GroupRideStatus.active
          : status == 'completed'
              ? GroupRideStatus.completed
              : GroupRideStatus.planned,
      members: members.map((m) => m.toEntity()).toList(),
      createdAt: createdAt,
      maxParticipants: maxParticipants,
    );
  }
}
