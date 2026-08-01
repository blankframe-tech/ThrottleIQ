import 'package:latlong2/latlong.dart';

import '../../domain/entities/group_ride_entity.dart';

/// Normalizes whatever Firestore hands back for a timestamp-ish field.
///
/// A field written with `FieldValue.serverTimestamp()` reads back as `null`
/// on the writer's own device until the server round-trip lands (the local
/// snapshot has no value yet), and a locally-written `DateTime` reads back as
/// a `Timestamp`. Both used to reach `(x as dynamic).toDate()`, which threw
/// on the null and took the whole group ride down with it.
DateTime? _toDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

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
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Rider',
      // Nullable in practice: a rider with no avatar is written as null by
      // some paths and '' by others, and `as String` on the null blew up the
      // whole group-ride parse (one avatar-less invitee = an unreadable ride).
      userPhotoUrl: data['userPhotoUrl'] as String? ?? '',
      joinedAt: _toDate(data['joinedAt']) ?? DateTime.now(),
      status: data['status'] as String? ?? 'joined',
      currentLat: (data['currentLat'] as num?)?.toDouble(),
      currentLng: (data['currentLng'] as num?)?.toDouble(),
      lastLocationUpdate: _toDate(data['lastLocationUpdate']),
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

  /// See [GroupRideEntity.memberIds] — flat uid arrays that exist purely so
  /// firestore.rules can test membership (rules cannot index into an array of
  /// maps like [members]).
  final List<String> memberIds;
  final List<String> invitedIds;

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
    this.memberIds = const [],
    this.invitedIds = const [],
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
      'memberIds': memberIds,
      'invitedIds': invitedIds,
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
      startTime: _toDate(data['startTime']) ?? DateTime.now(),
      routeId: data['routeId'] as String?,
      routePolyline: polylineList.isEmpty ? null : polylineList,
      status: data['status'] as String? ?? 'planned',
      members: membersList,
      memberIds:
          (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      invitedIds:
          (data['invitedIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: _toDate(data['createdAt']) ?? DateTime.now(),
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
      memberIds: memberIds,
      invitedIds: invitedIds,
      createdAt: createdAt,
      maxParticipants: maxParticipants,
    );
  }
}
