import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum GroupRideStatus { planned, active, completed }

class GroupRideMember extends Equatable {
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final DateTime joinedAt;
  final GroupRideMemberStatus status; // joined, declined, pending
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationUpdate;

  const GroupRideMember({
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.joinedAt,
    this.status = GroupRideMemberStatus.joined,
    this.currentLat,
    this.currentLng,
    this.lastLocationUpdate,
  });

  @override
  List<Object?> get props => [userId, joinedAt, currentLat, currentLng];
}

enum GroupRideMemberStatus { joined, declined, pending }

class GroupRideEntity extends Equatable {
  final String id;
  final String creatorId;
  final String creatorName;
  final String name;
  final String? description;
  final DateTime startTime;
  final String? routeId;
  final List<LatLng>? routePolyline;
  final GroupRideStatus status;
  final List<GroupRideMember> members;
  final DateTime createdAt;
  final int maxParticipants;

  const GroupRideEntity({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.name,
    this.description,
    required this.startTime,
    this.routeId,
    this.routePolyline,
    this.status = GroupRideStatus.planned,
    this.members = const [],
    required this.createdAt,
    this.maxParticipants = 20,
  });

  int get joinedMembersCount =>
      members.where((m) => m.status == GroupRideMemberStatus.joined).length;

  bool isFull => joinedMembersCount >= maxParticipants;

  GroupRideEntity copyWith({
    GroupRideStatus? status,
    List<GroupRideMember>? members,
  }) {
    return GroupRideEntity(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      name: name,
      description: description,
      startTime: startTime,
      routeId: routeId,
      routePolyline: routePolyline,
      status: status ?? this.status,
      members: members ?? this.members,
      createdAt: createdAt,
      maxParticipants: maxParticipants,
    );
  }

  @override
  List<Object?> get props => [id, creatorId, startTime, createdAt];
}
