import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/group_ride_entity.dart';
import '../models/group_ride_model.dart';

class GroupRideRepository {
  static final GroupRideRepository _instance =
      GroupRideRepository._internal();

  factory GroupRideRepository() => _instance;

  GroupRideRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new group ride.
  Future<String> createGroupRide({
    required String creatorId,
    required String creatorName,
    required String name,
    String? description,
    required DateTime startTime,
    String? routeId,
    List<LatLng>? routePolyline,
    int maxParticipants = 20,
  }) async {
    final groupRideRef = _firestore.collection('groupRides').doc();

    final groupRide = GroupRideModel(
      id: groupRideRef.id,
      creatorId: creatorId,
      creatorName: creatorName,
      name: name,
      description: description,
      startTime: startTime,
      routeId: routeId,
      routePolyline: routePolyline,
      status: 'planned',
      members: [
        GroupRideMemberModel(
          userId: creatorId,
          userName: creatorName,
          userPhotoUrl: '', // Will be filled from auth
          joinedAt: DateTime.now(),
          status: 'joined',
          currentLat: null,
          currentLng: null,
          lastLocationUpdate: null,
        ),
      ],
      createdAt: DateTime.now(),
      maxParticipants: maxParticipants,
    );

    await groupRideRef.set(groupRide.toFirestore());
    return groupRideRef.id;
  }

  /// Gets a group ride by ID.
  Future<GroupRideEntity?> getGroupRide(String groupRideId) async {
    final doc =
        await _firestore.collection('groupRides').doc(groupRideId).get();
    if (!doc.exists) return null;

    final model = GroupRideModel.fromFirestore(doc.data()!, doc.id);
    return model.toEntity();
  }

  /// Gets upcoming group rides.
  Future<List<GroupRideEntity>> getUpcomingGroupRides({
    int limit = 20,
  }) async {
    final now = DateTime.now();
    final querySnapshot = await _firestore
        .collection('groupRides')
        .where('status', isEqualTo: 'planned')
        .where('startTime', isGreaterThan: now)
        .orderBy('startTime', descending: false)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) =>
            GroupRideModel.fromFirestore(doc.data(), doc.id).toEntity())
        .toList();
  }

  /// Gets group rides created by a specific user.
  Future<List<GroupRideEntity>> getUserGroupRides(String userId) async {
    final querySnapshot = await _firestore
        .collection('groupRides')
        .where('creatorId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) =>
            GroupRideModel.fromFirestore(doc.data(), doc.id).toEntity())
        .toList();
  }

  /// Invites users to a group ride.
  Future<void> inviteUsers({
    required String groupRideId,
    required List<String> userIds,
  }) async {
    final batch = _firestore.batch();

    for (final userId in userIds) {
      final memberRef = _firestore
          .collection('groupRides')
          .doc(groupRideId)
          .collection('invitations')
          .doc(userId);

      batch.set(memberRef, {
        'userId': userId,
        'status': 'pending',
        'invitedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Accepts a group ride invitation.
  Future<void> acceptInvitation({
    required String groupRideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
  }) async {
    final docRef = _firestore.collection('groupRides').doc(groupRideId);

    await docRef.update({
      'members': FieldValue.arrayUnion([
        {
          'userId': userId,
          'userName': userName,
          'userPhotoUrl': userPhotoUrl,
          'joinedAt': FieldValue.serverTimestamp(),
          'status': 'joined',
          'currentLat': null,
          'currentLng': null,
          'lastLocationUpdate': null,
        }
      ]),
    });

    // Delete invitation
    await docRef
        .collection('invitations')
        .doc(userId)
        .delete();
  }

  /// Declines a group ride invitation.
  Future<void> declineInvitation({
    required String groupRideId,
    required String userId,
  }) async {
    await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .collection('invitations')
        .doc(userId)
        .delete();
  }

  /// Updates a member's live location.
  Future<void> updateMemberLocation({
    required String groupRideId,
    required String userId,
    required double lat,
    required double lng,
  }) async {
    await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .collection('memberLocations')
        .doc(userId)
        .set({
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Gets live member locations.
  Future<Map<String, Map<String, dynamic>>> getMemberLocations(
    String groupRideId,
  ) async {
    final querySnapshot = await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .collection('memberLocations')
        .get();

    final locations = <String, Map<String, dynamic>>{};
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      locations[data['userId']] = {
        'lat': data['lat'],
        'lng': data['lng'],
        'timestamp': data['timestamp'],
      };
    }

    return locations;
  }

  /// Streams live member locations.
  Stream<Map<String, Map<String, dynamic>>> streamMemberLocations(
    String groupRideId,
  ) {
    return _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .collection('memberLocations')
        .snapshots()
        .map((snapshot) {
      final locations = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        locations[data['userId']] = {
          'lat': data['lat'],
          'lng': data['lng'],
          'timestamp': data['timestamp'],
        };
      }
      return locations;
    });
  }

  /// Starts a group ride (changes status to active).
  Future<void> startGroupRide(String groupRideId) async {
    await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .update({'status': 'active'});
  }

  /// Ends a group ride (changes status to completed).
  Future<void> endGroupRide(String groupRideId) async {
    await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .update({'status': 'completed'});
  }

  /// Removes a member from a group ride.
  Future<void> removeMember({
    required String groupRideId,
    required String userId,
  }) async {
    final doc = await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .get();

    final members = List<Map<String, dynamic>>.from(doc['members'] ?? []);
    members.removeWhere((m) => m['userId'] == userId);

    await _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .update({'members': members});
  }

  /// Deletes a group ride.
  Future<void> deleteGroupRide(String groupRideId) async {
    final docRef = _firestore.collection('groupRides').doc(groupRideId);

    // Delete member locations
    final locations = await docRef.collection('memberLocations').get();
    for (final location in locations.docs) {
      await location.reference.delete();
    }

    // Delete invitations
    final invitations = await docRef.collection('invitations').get();
    for (final invitation in invitations.docs) {
      await invitation.reference.delete();
    }

    // Delete the group ride
    await docRef.delete();
  }
}
