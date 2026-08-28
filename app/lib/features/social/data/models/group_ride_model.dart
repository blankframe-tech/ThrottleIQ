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

  /// The document body written to `groupRides/{id}/members/{uid}`.
  ///
  /// `userId` is stored as well as being the document id — the two are always
  /// the same, but a reader that already has the map shouldn't have to carry
  /// the id alongside it. [fromDocument] trusts the id, not the field.
  Map<String, dynamic> toDocument() {
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

  /// Reads one `groupRides/{id}/members/{uid}` document.
  ///
  /// [docId] wins over the `userId` field for the same reason
  /// `GroupRideRepository._locationsFrom` keys off the document id: the id is
  /// what firestore.rules pin the write to, so it is the only value that
  /// cannot be spoofed or left missing by a partial write.
  factory GroupRideMemberModel.fromDocument(
    Map<String, dynamic> data,
    String docId,
  ) {
    return GroupRideMemberModel.fromFirestore({...data, 'userId': docId});
  }

  /// Reads one entry of a *legacy* parent-document `members` array.
  ///
  /// Group rides created before members moved to their own subcollection
  /// stored the whole roster inline on `groupRides/{id}`. Kept so those rides
  /// still render — see `mergeGroupRideMembers`.
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

class VoiceNoteModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String audioUrl;
  final int durationMs;
  final DateTime? createdAt;

  VoiceNoteModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.audioUrl,
    required this.durationMs,
    this.createdAt,
  });

  /// The document body written to `groupRides/{id}/voiceNotes/{noteId}`.
  /// `createdAt` is always `FieldValue.serverTimestamp()` at the call site
  /// (the firestore.rules create clause requires it), never a plain
  /// `DateTime` — so it is deliberately not a field here.
  Map<String, dynamic> toDocument() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'audioUrl': audioUrl,
      'durationMs': durationMs,
    };
  }

  factory VoiceNoteModel.fromDocument(
    Map<String, dynamic> data,
    String docId,
  ) {
    return VoiceNoteModel(
      id: docId,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Rider',
      senderPhotoUrl: data['senderPhotoUrl'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(data['createdAt']),
    );
  }

  VoiceNoteEntity toEntity() {
    return VoiceNoteEntity(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      audioUrl: audioUrl,
      durationMs: durationMs,
      createdAt: createdAt,
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

  /// The roster as it was stored *inline on the parent document* by group
  /// rides created before members moved to `groupRides/{id}/members/{uid}`.
  ///
  /// Read-only legacy: [toFirestore] no longer writes it, because a rule can't
  /// project a field out of an array of maps and so couldn't stop an accepting
  /// invitee from rewriting everyone else's display name. Current rides leave
  /// this empty and the roster is read from the subcollection.
  final List<GroupRideMemberModel> members;

  /// See [GroupRideEntity.memberIds] — flat uid arrays that exist so
  /// firestore.rules can test membership on the parent document without
  /// reading the members subcollection.
  final List<String> memberIds;
  final List<String> invitedIds;

  final DateTime createdAt;
  final int maxParticipants;

  /// The shareable code a rider without an invite can type in to join (see
  /// `group_ride_join_code.dart`). Empty for rides created before this
  /// existed — they simply have no code-join door, invite-only as before.
  final String joinCode;

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
    this.joinCode = '',
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
      // No 'members' key: the roster lives in the members subcollection now.
      // Writing it here as well would keep the array of maps inside the
      // parent's `allow update` surface, which is the whole reason an
      // accepting invitee could scramble other riders' names.
      'memberIds': memberIds,
      'invitedIds': invitedIds,
      'createdAt': createdAt,
      'maxParticipants': maxParticipants,
      'joinCode': joinCode,
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
      joinCode: data['joinCode'] as String? ?? '',
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
      joinCode: joinCode,
    );
  }
}
