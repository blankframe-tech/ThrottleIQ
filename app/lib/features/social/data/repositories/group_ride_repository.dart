import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/group_ride_entity.dart';
import '../models/group_ride_model.dart';

/// One rider picked in the "Ride with friends" friend picker, carried into
/// [GroupRideRepository.createGroupRide] so their name/avatar are baked into
/// the ride's `members` array as a *pending* entry straight away. Without
/// this the map's member list could only say "someone hasn't joined yet" —
/// the name wouldn't exist anywhere until they accepted.
class GroupRideInvitee {
  final String userId;
  final String userName;
  final String userPhotoUrl;

  const GroupRideInvitee({
    required this.userId,
    required this.userName,
    this.userPhotoUrl = '',
  });
}

class GroupRideRepository {
  static final GroupRideRepository _instance =
      GroupRideRepository._internal();

  factory GroupRideRepository() => _instance;

  GroupRideRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new group ride.
  ///
  /// [invitees] are written into `members` immediately with status `pending`
  /// (and into `invitedIds`), so the shared map can list who's been asked but
  /// hasn't shown up yet. They still need [inviteUsers] to get their own
  /// invitation document — this only seeds the roster.
  Future<String> createGroupRide({
    required String creatorId,
    required String creatorName,
    String creatorPhotoUrl = '',
    required String name,
    String? description,
    required DateTime startTime,
    String? routeId,
    List<LatLng>? routePolyline,
    List<GroupRideInvitee> invitees = const [],
    String status = 'planned',
    int maxParticipants = 20,
  }) async {
    final groupRideRef = _firestore.collection('groupRides').doc();
    final now = DateTime.now();

    final groupRide = GroupRideModel(
      id: groupRideRef.id,
      creatorId: creatorId,
      creatorName: creatorName,
      name: name,
      description: description,
      startTime: startTime,
      routeId: routeId,
      routePolyline: routePolyline,
      status: status,
      members: [
        GroupRideMemberModel(
          userId: creatorId,
          userName: creatorName,
          userPhotoUrl: creatorPhotoUrl,
          joinedAt: now,
          status: 'joined',
          currentLat: null,
          currentLng: null,
          lastLocationUpdate: null,
        ),
        for (final invitee in invitees)
          GroupRideMemberModel(
            userId: invitee.userId,
            userName: invitee.userName,
            userPhotoUrl: invitee.userPhotoUrl,
            joinedAt: now,
            status: 'pending',
            currentLat: null,
            currentLng: null,
            lastLocationUpdate: null,
          ),
      ],
      memberIds: [creatorId],
      invitedIds: invitees.map((i) => i.userId).toList(),
      createdAt: now,
      maxParticipants: maxParticipants,
    );

    await groupRideRef.set(groupRide.toFirestore());
    return groupRideRef.id;
  }

  /// Live view of one group ride — members joining, statuses flipping.
  ///
  /// Emits `null` if the ride is deleted while someone still has the map
  /// open, rather than erroring the stream.
  Stream<GroupRideEntity?> watchGroupRide(String groupRideId) {
    return _firestore
        .collection('groupRides')
        .doc(groupRideId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return GroupRideModel.fromFirestore(data, doc.id).toEntity();
    });
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

  /// Accepts a group ride invitation: flips the rider's pending entry in
  /// `members` to joined, adds them to `memberIds` (which is what the
  /// firestore rules gate location writes on) and clears them from
  /// `invitedIds`.
  ///
  /// Runs as a transaction and *rewrites* the members array rather than
  /// `arrayUnion`-ing a new element, for two reasons: the rider is already in
  /// the array as `pending` (createGroupRide seeds them), so a union would
  /// leave a duplicate ghost entry; and `FieldValue.serverTimestamp()` — what
  /// this used to put in `joinedAt` — is rejected outright by Firestore
  /// inside an arrayUnion payload, so the old version threw before it ever
  /// wrote anything.
  ///
  /// Idempotent: accepting twice (double-tapping the notification) is a
  /// no-op the second time.
  Future<void> acceptInvitation({
    required String groupRideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
  }) async {
    final docRef = _firestore.collection('groupRides').doc(groupRideId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};

      final members = List<Map<String, dynamic>>.from(
        (data['members'] as List<dynamic>? ?? const [])
            .map((m) => Map<String, dynamic>.from(m as Map)),
      );

      final index = members.indexWhere((m) => m['userId'] == userId);
      final joinedEntry = <String, dynamic>{
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        // A plain DateTime, not serverTimestamp() — see doc comment.
        'joinedAt': DateTime.now(),
        'status': 'joined',
        'currentLat': index >= 0 ? members[index]['currentLat'] : null,
        'currentLng': index >= 0 ? members[index]['currentLng'] : null,
        'lastLocationUpdate':
            index >= 0 ? members[index]['lastLocationUpdate'] : null,
      };
      if (index >= 0) {
        members[index] = joinedEntry;
      } else {
        members.add(joinedEntry);
      }

      txn.update(docRef, {
        'members': members,
        'memberIds': FieldValue.arrayUnion([userId]),
        'invitedIds': FieldValue.arrayRemove([userId]),
      });
    });

    // Best-effort: the invite doc is only a to-do marker, and losing the race
    // to delete it must not make a successful join look like a failure.
    try {
      await docRef.collection('invitations').doc(userId).delete();
    } catch (_) {/* already gone, or rules raced us */}
  }

  /// Declines a group ride invitation — marks the rider's roster entry
  /// `declined` and drops them from `invitedIds` so they lose read access.
  Future<void> declineInvitation({
    required String groupRideId,
    required String userId,
  }) async {
    final docRef = _firestore.collection('groupRides').doc(groupRideId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};

      final members = List<Map<String, dynamic>>.from(
        (data['members'] as List<dynamic>? ?? const [])
            .map((m) => Map<String, dynamic>.from(m as Map)),
      );
      final index = members.indexWhere((m) => m['userId'] == userId);
      if (index >= 0) {
        members[index] = {...members[index], 'status': 'declined'};
      }

      txn.update(docRef, {
        'members': members,
        'invitedIds': FieldValue.arrayRemove([userId]),
      });
    });

    try {
      await docRef.collection('invitations').doc(userId).delete();
    } catch (_) {/* already gone */}
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

    return _locationsFrom(querySnapshot.docs);
  }

  /// Shared by [getMemberLocations] and [streamMemberLocations].
  ///
  /// Keys off the *document id* rather than the `userId` field: the two are
  /// always the same (locations are written at `memberLocations/{uid}`, which
  /// is also what the security rules pin writes to), and the field can be
  /// missing on a partially-written document — which used to key the map to
  /// `null` and blow up the whole snapshot.
  Map<String, Map<String, dynamic>> _locationsFrom(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final locations = <String, Map<String, dynamic>>{};
    for (final doc in docs) {
      final data = doc.data();
      if (data['lat'] == null || data['lng'] == null) continue;
      locations[doc.id] = {
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
        .map((snapshot) => _locationsFrom(snapshot.docs));
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

  /// A rider removing *themselves* from a ride they joined ("Leave").
  ///
  /// Distinct from [removeMember] (a creator kicking someone) because the
  /// firestore rules treat the two very differently: self-removal is allowed
  /// for any joined member, kicking is creator-only. Also drops their live
  /// location document so the rest of the group stops seeing a marker that
  /// will never move again.
  ///
  /// The creator leaving would orphan the ride, so for them this ends it
  /// instead (status → completed).
  Future<void> leaveGroupRide({
    required String groupRideId,
    required String userId,
  }) async {
    final docRef = _firestore.collection('groupRides').doc(groupRideId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};

      if (data['creatorId'] == userId) {
        txn.update(docRef, {'status': 'completed'});
        return;
      }

      final members = (data['members'] as List<dynamic>? ?? const [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .where((m) => m['userId'] != userId)
          .toList();

      txn.update(docRef, {
        'members': members,
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    });

    try {
      await docRef.collection('memberLocations').doc(userId).delete();
    } catch (_) {/* nothing published yet, or already gone */}
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

    await _firestore.collection('groupRides').doc(groupRideId).update({
      'members': members,
      // memberIds/invitedIds must never drift from members — firestore.rules
      // reads them, not the array of maps, to decide who may write locations.
      'memberIds': FieldValue.arrayRemove([userId]),
      'invitedIds': FieldValue.arrayRemove([userId]),
    });
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
