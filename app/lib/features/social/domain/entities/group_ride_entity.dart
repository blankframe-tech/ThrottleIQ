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

  /// Uids of riders who have actually joined, denormalized out of [members].
  ///
  /// [members] is an array of maps, and Firestore security rules have no way
  /// to project a field out of an array of maps — `request.auth.uid in
  /// resource.data.members` can't be expressed. This flat array is what the
  /// `groupRides` rules test membership against; it is written in the same
  /// operation as [members] and must never drift from it.
  final List<String> memberIds;

  /// Uids invited but not yet joined (the pending half of [members]). Lets an
  /// invitee read the ride document — and its live locations — from the
  /// moment they're invited, without being able to write locations yet.
  final List<String> invitedIds;

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
    this.memberIds = const [],
    this.invitedIds = const [],
    required this.createdAt,
    this.maxParticipants = 20,
  });

  int get joinedMembersCount =>
      members.where((m) => m.status == GroupRideMemberStatus.joined).length;

  bool get isFull => joinedMembersCount >= maxParticipants;

  /// Members that have joined, ordered by uid. The ordering is what makes
  /// marker colours stable — see `colorForMember`.
  List<GroupRideMember> get joinedMembers {
    final joined = members
        .where((m) => m.status == GroupRideMemberStatus.joined)
        .toList()
      ..sort((a, b) => a.userId.compareTo(b.userId));
    return joined;
  }

  GroupRideEntity copyWith({
    GroupRideStatus? status,
    List<GroupRideMember>? members,
    List<String>? memberIds,
    List<String>? invitedIds,
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
      memberIds: memberIds ?? this.memberIds,
      invitedIds: invitedIds ?? this.invitedIds,
      createdAt: createdAt,
      maxParticipants: maxParticipants,
    );
  }

  @override
  List<Object?> get props => [id, creatorId, startTime, createdAt];
}
