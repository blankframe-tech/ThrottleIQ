import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/group_ride_entity.dart';
import '../../domain/utilities/group_ride_members.dart';
import '../models/group_ride_model.dart';

/// One rider picked in the "Ride with friends" friend picker, carried into
/// [GroupRideRepository.createGroupRide] so their name/avatar are written to
/// their member document as a *pending* entry straight away. Without this the
/// map's member list could only say "someone hasn't joined yet" — the name
/// wouldn't exist anywhere until they accepted.
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

  DocumentReference<Map<String, dynamic>> _rideRef(String groupRideId) =>
      _firestore.collection('groupRides').doc(groupRideId);

  /// One document per rider at `groupRides/{id}/members/{uid}`.
  ///
  /// The roster used to be an array of maps on the parent document. Rules
  /// cannot project a field out of an array of maps, so the rule permitting an
  /// invitee to accept could only bound the array's length — the accepting
  /// rider could rewrite everybody else's name in the same write. As
  /// documents, the rule is exactly expressible: the `{uid}` wildcard is
  /// pinned to `request.auth.uid`, the same shape `memberLocations/{uid}`
  /// already uses.
  CollectionReference<Map<String, dynamic>> _membersRef(String groupRideId) =>
      _rideRef(groupRideId).collection('members');

  /// Creates a new group ride.
  ///
  /// The creator's member document and one `pending` document per invitee are
  /// written in the same batch as the ride, so the shared map can list who's
  /// been asked but hasn't shown up yet. Invitees still need [inviteUsers] to
  /// get their own invitation document — this only seeds the roster.
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
      memberIds: [creatorId],
      invitedIds: invitees.map((i) => i.userId).toList(),
      createdAt: now,
      maxParticipants: maxParticipants,
    );

    final roster = <GroupRideMemberModel>[
      GroupRideMemberModel(
        userId: creatorId,
        userName: creatorName,
        userPhotoUrl: creatorPhotoUrl,
        joinedAt: now,
        status: 'joined',
      ),
      for (final invitee in invitees)
        GroupRideMemberModel(
          userId: invitee.userId,
          userName: invitee.userName,
          userPhotoUrl: invitee.userPhotoUrl,
          joinedAt: now,
          status: 'pending',
        ),
    ];

    // One batch: a ride must never exist without its creator on the roster,
    // and a roster must never exist without its ride.
    final batch = _firestore.batch();
    batch.set(groupRideRef, groupRide.toFirestore());
    final members = groupRideRef.collection('members');
    for (final member in roster) {
      batch.set(members.doc(member.userId), member.toDocument());
    }
    await batch.commit();

    return groupRideRef.id;
  }

  /// Live view of one group ride's roster.
  ///
  /// Separate from [watchGroupRide] because it's a separate document set —
  /// callers that need both combine them with `mergeGroupRideMembers`, which
  /// also folds in the inline roster of rides created before this collection
  /// existed.
  Stream<List<GroupRideMember>> watchGroupRideMembers(String groupRideId) {
    return _membersRef(groupRideId).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) =>
                  GroupRideMemberModel.fromDocument(doc.data(), doc.id)
                      .toEntity())
              .toList(),
        );
  }

  /// One-shot read of the members subcollection.
  Future<List<GroupRideMember>> getGroupRideMembers(String groupRideId) async {
    final snapshot = await _membersRef(groupRideId).get();
    return snapshot.docs
        .map((doc) =>
            GroupRideMemberModel.fromDocument(doc.data(), doc.id).toEntity())
        .toList();
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

  /// Gets a group ride by ID, roster included.
  Future<GroupRideEntity?> getGroupRide(String groupRideId) async {
    final doc = await _rideRef(groupRideId).get();
    if (!doc.exists) return null;

    final ride = GroupRideModel.fromFirestore(doc.data()!, doc.id).toEntity();
    return ride.copyWith(
      members: mergeGroupRideMembers(
        legacy: ride.members,
        fromSubcollection: await getGroupRideMembers(groupRideId),
      ),
    );
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

  /// Invites riders to a group ride.
  ///
  /// Writes three things per invitee, in one batch: the invitation marker at
  /// `invitations/{uid}` (the to-do the notification acts on), a `pending`
  /// member document so the roster can name them before they accept, and their
  /// uid on the parent's `invitedIds` — which is what firestore.rules read to
  /// let them see the ride at all.
  ///
  /// Takes [GroupRideInvitee]s rather than bare uids because the roster entry
  /// needs a name; a uid alone would put "Rider" on the map. Only the ride's
  /// creator may call this — the rules refuse anyone else on all three writes.
  ///
  /// The member documents overlap with what [createGroupRide] already seeded
  /// for the same riders; they're written with `merge` so re-inviting somebody
  /// tops up their name rather than resetting fields it doesn't know about.
  Future<void> inviteUsers({
    required String groupRideId,
    required List<GroupRideInvitee> invitees,
  }) async {
    if (invitees.isEmpty) return;

    final rideRef = _rideRef(groupRideId);
    final batch = _firestore.batch();

    for (final invitee in invitees) {
      batch.set(rideRef.collection('invitations').doc(invitee.userId), {
        'userId': invitee.userId,
        'status': 'pending',
        'invitedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _membersRef(groupRideId).doc(invitee.userId),
        {
          'userId': invitee.userId,
          'userName': invitee.userName,
          'userPhotoUrl': invitee.userPhotoUrl,
          'joinedAt': DateTime.now(),
          'status': 'pending',
        },
        SetOptions(merge: true),
      );
    }

    batch.update(rideRef, {
      'invitedIds':
          FieldValue.arrayUnion([for (final i in invitees) i.userId]),
    });

    await batch.commit();
  }

  /// Accepts a group ride invitation: flips the rider's own member document to
  /// `joined`, adds them to `memberIds` (which is what the firestore rules
  /// gate location writes on) and clears them from `invitedIds`.
  ///
  /// The rider writes only `members/{their own uid}` and the two flat uid
  /// arrays — never anybody else's roster entry. That is the whole point of
  /// members being documents: while the roster was an array of maps on the
  /// parent, a rule could bound its *size* but not its contents, so accepting
  /// an invitation was enough to rewrite every other rider's display name.
  ///
  /// Still a transaction, and it still never puts
  /// `FieldValue.serverTimestamp()` into the payload — the earlier version put
  /// one inside an `arrayUnion`, which Firestore rejects outright, so it threw
  /// before writing anything.
  ///
  /// Idempotent: accepting twice (double-tapping the notification) leaves the
  /// original `joinedAt` alone, so the second tap changes nothing.
  Future<void> acceptInvitation({
    required String groupRideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
  }) async {
    final rideRef = _rideRef(groupRideId);
    final memberRef = _membersRef(groupRideId).doc(userId);

    await _firestore.runTransaction((txn) async {
      // Every read has to precede every write in a Firestore transaction.
      final rideSnap = await txn.get(rideRef);
      if (!rideSnap.exists) return;
      final existing = (await txn.get(memberRef)).data();

      final entry = GroupRideMemberModel(
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        // A plain DateTime, not serverTimestamp() — see doc comment.
        joinedAt: DateTime.now(),
        status: 'joined',
        currentLat: (existing?['currentLat'] as num?)?.toDouble(),
        currentLng: (existing?['currentLng'] as num?)?.toDouble(),
      ).toDocument();

      // Keep the moment they *first* joined rather than the moment of the
      // repeat tap.
      if (existing?['status'] == 'joined' && existing?['joinedAt'] != null) {
        entry['joinedAt'] = existing!['joinedAt'];
      }
      entry['lastLocationUpdate'] = existing?['lastLocationUpdate'];

      txn.set(memberRef, entry);
      txn.update(rideRef, {
        'memberIds': FieldValue.arrayUnion([userId]),
        'invitedIds': FieldValue.arrayRemove([userId]),
      });
    });

    // Best-effort: the invite doc is only a to-do marker, and losing the race
    // to delete it must not make a successful join look like a failure.
    try {
      await rideRef.collection('invitations').doc(userId).delete();
    } catch (_) {/* already gone, or rules raced us */}
  }

  /// Declines a group ride invitation — marks the rider's own member document
  /// `declined` and drops them from `invitedIds` so they lose read access.
  ///
  /// Merged rather than overwritten: the name and avatar on that document were
  /// written by the ride's creator at invite time and this caller doesn't have
  /// them, so a full set would blank out the roster entry it is only meant to
  /// restatus.
  Future<void> declineInvitation({
    required String groupRideId,
    required String userId,
  }) async {
    final rideRef = _rideRef(groupRideId);
    final memberRef = _membersRef(groupRideId).doc(userId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(rideRef);
      if (!snap.exists) return;

      txn.set(
        memberRef,
        {'userId': userId, 'status': 'declined'},
        SetOptions(merge: true),
      );
      txn.update(rideRef, {
        'invitedIds': FieldValue.arrayRemove([userId]),
      });
    });

    try {
      await rideRef.collection('invitations').doc(userId).delete();
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

  /// Sends one push-to-talk clip to `groupRides/{id}/voiceNotes/{noteId}`.
  ///
  /// Create-only — firestore.rules refuses update/delete on this
  /// collection entirely, so a sent clip can never be edited or retracted.
  /// Only a joined member (not merely an invitee) may call this; the rules
  /// enforce that independently of this method.
  Future<void> sendVoiceNote({
    required String groupRideId,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String audioUrl,
    required int durationMs,
  }) async {
    final model = VoiceNoteModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      audioUrl: audioUrl,
      durationMs: durationMs,
    );
    await _rideRef(groupRideId).collection('voiceNotes').add({
      ...model.toDocument(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live view of a group ride's voice notes, oldest first.
  Stream<List<VoiceNoteEntity>> watchVoiceNotes(String groupRideId) {
    return _rideRef(groupRideId)
        .collection('voiceNotes')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                VoiceNoteModel.fromDocument(doc.data(), doc.id).toEntity())
            .toList());
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
    final rideRef = _rideRef(groupRideId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(rideRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};

      if (data['creatorId'] == userId) {
        txn.update(rideRef, {'status': 'completed'});
        return;
      }

      // Their own member document and their own uid — the only two things the
      // rules let a departing rider touch.
      txn.delete(_membersRef(groupRideId).doc(userId));
      txn.update(rideRef, {
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    });

    try {
      await rideRef.collection('memberLocations').doc(userId).delete();
    } catch (_) {/* nothing published yet, or already gone */}
  }

  /// The creator removing somebody else from a ride ("kick"). See
  /// [leaveGroupRide] for the self-removal path, which the rules treat
  /// differently.
  ///
  /// Also strips the rider from the parent's legacy inline `members` array if
  /// this ride has one: the creator is the only caller who is allowed to
  /// rewrite that array, so a ride created before the roster moved to its own
  /// subcollection can still be tidied up here.
  Future<void> removeMember({
    required String groupRideId,
    required String userId,
  }) async {
    final rideRef = _rideRef(groupRideId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(rideRef);
      if (!snap.exists) return;

      final legacy = (snap.data()?['members'] as List<dynamic>?)
          ?.map((m) => Map<String, dynamic>.from(m as Map))
          .where((m) => m['userId'] != userId)
          .toList();

      txn.delete(_membersRef(groupRideId).doc(userId));
      txn.update(rideRef, {
        // memberIds/invitedIds must never drift from the roster —
        // firestore.rules read them, not the member documents, to decide who
        // may write locations.
        'memberIds': FieldValue.arrayRemove([userId]),
        'invitedIds': FieldValue.arrayRemove([userId]),
        if (legacy != null) 'members': legacy,
      });
    });

    try {
      await rideRef.collection('memberLocations').doc(userId).delete();
    } catch (_) {/* nothing published yet, or already gone */}
  }

  /// Deletes a group ride and everything hanging off it.
  Future<void> deleteGroupRide(String groupRideId) async {
    final docRef = _rideRef(groupRideId);

    for (final subcollection in [
      'memberLocations',
      'invitations',
      'members',
      'voiceNotes',
    ]) {
      final snapshot = await docRef.collection(subcollection).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    // Delete the group ride
    await docRef.delete();
  }
}
