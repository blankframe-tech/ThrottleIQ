import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/cloudinary_upload_service.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/utilities/privacy_zone_clipper.dart';
import '../models/ride_share_model.dart';
import 'follow_repository.dart';

class RideShareRepository {
  static final RideShareRepository _instance =
      RideShareRepository._internal();

  factory RideShareRepository() => _instance;

  RideShareRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryUploadService _uploadService = CloudinaryUploadService();
  final FollowRepository _followRepository = FollowRepository();

  /// Uploads a rider-taken ride/bike photo (via Cloudinary — see
  /// [CloudinaryUploadService]) and returns its public URL.
  Future<String> uploadRidePhoto(String uid, String rideId, File file) {
    return _uploadService.upload(file, folder: 'rideShares/$uid');
  }

  /// Shares a ride and applies privacy zones.
  ///
  /// [audience] is `public` / `followers` / `mutual`. Firestore rules can't
  /// run a per-doc follow-graph lookup for a list query, so for the latter
  /// two we materialize the visible uid set into `allowedUserIds` right now
  /// (a snapshot at share time — new followers don't retroactively gain
  /// access, which is the accepted trade-off documented in HANDOFF_V2.md §3).
  Future<String> shareRide({
    required String rideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String bikeId,
    required String bikeName,
    required String bikeType,
    required DateTime rideDate,
    required double distanceKm,
    required int durationSeconds,
    required double maxSpeedKmh,
    required List<LatLng> polyline,
    required String? mapSnapshotUrl,
    required String audience,
    String? photoUrl,
    String? routeId,
  }) async {
    // Apply privacy-zone clipping (strips ~200 m off each end to hide
    // home/work). On a short or near-home ride the clip can consume the whole
    // track — that must NOT block sharing (this was the "share throws an
    // error" bug). Instead we share with NO route line at all, which is the
    // privacy-safe outcome anyway: the ride still posts, the feed card just
    // shows stats without a map trace.
    final clippedPolyline = PrivacyZoneClipper.clipPolyline(polyline);

    final allowedUserIds = switch (audience) {
      'followers' => await _followRepository.getFollowers(userId),
      'mutual' => await _followRepository.getMutuals(userId),
      _ => const <String>[],
    };

    final sharedRide = RideShareModel(
      id: rideId,
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
      polyline: clippedPolyline,
      mapSnapshotUrl: mapSnapshotUrl,
      likes: 0,
      comments: 0,
      isLikedByCurrentUser: false,
      createdAt: DateTime.now(),
      audience: audience,
      allowedUserIds: allowedUserIds,
      routeId: routeId,
      photoUrl: photoUrl,
    );

    final docRef = _firestore.collection('rides').doc(rideId);
    final existing = await docRef.get();

    final data = sharedRide.toFirestore();
    if (existing.exists) {
      // Don't wipe engagement accumulated since the ride was first shared.
      data.remove('likes');
      data.remove('comments');
      data.remove('upvotes');
      data.remove('downvotes');
    }
    await docRef.set(data, SetOptions(merge: true));

    return rideId;
  }

  /// Gets a shared ride by ID.
  Future<SharedRideEntity?> getSharedRide(String rideId) async {
    final doc = await _firestore.collection('rides').doc(rideId).get();
    if (!doc.exists) return null;

    final model = RideShareModel.fromFirestore(
      doc.data()!,
      doc.id,
    );
    return model.toEntity();
  }

  /// Public rides (for discovery). Lines up with the `audience == 'public'`
  /// clause of `rideVisibleTo()` in firestore.rules.
  Future<List<SharedRideEntity>> getPublicRides({int limit = 20}) async {
    final snap = await _firestore
        .collection('rides')
        .where('audience', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _hydrate(_toEntities(snap));
  }

  /// Rides materialized as visible to the signed-in rider (followers/mutual
  /// shares). Lines up with the `allowedUserIds arrayContains me` clause —
  /// AND its `audience in ['followers','mutual']` co-condition. Firestore
  /// can't prove a rule's AND'd condition true unless the query itself is
  /// constrained on it too: `rideVisibleTo()`'s matching branch is
  /// `audience in ['followers','mutual'] && uid in allowedUserIds`, so a
  /// query filtered ONLY on `allowedUserIds` (no explicit `audience` filter)
  /// can't be statically verified against that branch — Firestore rejects
  /// the whole query with permission-denied, even though every real
  /// document actually matching would pass (allowedUserIds is only ever
  /// populated when audience is followers/mutual, but that's an app-level
  /// write-time invariant, not something the query itself asserts). Adding
  /// the explicit audience filter here makes the query prove what the rule
  /// needs, matching firestore.indexes.json's composite index.
  Future<List<SharedRideEntity>> getSharedToMe(String uid, {int limit = 20}) async {
    final snap = await _firestore
        .collection('rides')
        .where('allowedUserIds', arrayContains: uid)
        .where('audience', whereIn: ['followers', 'mutual'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _hydrate(_toEntities(snap));
  }

  /// The signed-in rider's own shared rides, regardless of audience. Lines
  /// up with the `userId == me` (always-visible-to-owner) clause.
  Future<List<SharedRideEntity>> getMyRides(String uid, {int limit = 20}) async {
    final snap = await _firestore
        .collection('rides')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _hydrate(_toEntities(snap));
  }

  List<SharedRideEntity> _toEntities(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map((doc) => RideShareModel.fromFirestore(doc.data(), doc.id).toEntity())
        .toList();
  }

  /// Hydrates the signed-in rider's like/vote state onto each ride —
  /// entity-only fields never stored on the ride doc itself.
  Future<List<SharedRideEntity>> _hydrate(List<SharedRideEntity> entities) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || entities.isEmpty) return entities;

    final likedFlags = await Future.wait(entities.map((ride) => _firestore
        .collection('rides')
        .doc(ride.id)
        .collection('likes')
        .doc(currentUserId)
        .get()
        .then((doc) => doc.exists)));

    final votes = await Future.wait(
        entities.map((ride) => getMyVote(ride.id, currentUserId)));

    return [
      for (var i = 0; i < entities.length; i++)
        entities[i].copyWith(isLikedByCurrentUser: likedFlags[i], myVote: votes[i]),
    ];
  }

  /// Likes or unlikes a ride. Idempotent: checks the like doc's existence
  /// inside a transaction so re-liking/re-unliking never double-counts.
  Future<void> toggleLike(String rideId, String userId, bool like) async {
    final docRef = _firestore.collection('rides').doc(rideId);
    final likeRef = docRef.collection('likes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final alreadyLiked = likeDoc.exists;
      if (alreadyLiked == like) return; // Already in the desired state.

      if (like) {
        transaction.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(docRef, {'likes': FieldValue.increment(1)});
      } else {
        transaction.delete(likeRef);
        transaction.update(docRef, {'likes': FieldValue.increment(-1)});
      }
    });
  }

  /// The signed-in rider's own vote on a ride, if any (1 upvote / -1
  /// downvote), read from `votes/{uid}`.
  Future<int?> getMyVote(String rideId, String uid) async {
    final doc = await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('votes')
        .doc(uid)
        .get();
    return doc.data()?['value'] as int?;
  }

  /// Casts, changes, or clears a vote. [value] is 1 (upvote) or -1
  /// (downvote); calling it again with the same value toggles the vote off.
  ///
  /// Writes exactly one of three shapes so every possible write stays within
  /// firestore.rules' bounded ±1-per-field vote clause: a fresh vote bumps
  /// only its own tally by 1; toggling off drops the vote doc and un-bumps
  /// that same tally by 1; flipping (e.g. down→up) moves both tallies by 1
  /// in the same write.
  Future<void> vote(String rideId, String uid, int value) async {
    assert(value == 1 || value == -1);
    final docRef = _firestore.collection('rides').doc(rideId);
    final voteRef = docRef.collection('votes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(voteRef);
      final previous = existing.data()?['value'] as int?;
      if (previous == value) {
        // Toggle off.
        transaction.delete(voteRef);
        transaction.update(docRef, {
          value == 1 ? 'upvotes' : 'downvotes': FieldValue.increment(-1),
        });
        return;
      }

      transaction.set(voteRef, {'value': value});
      if (previous == null) {
        transaction.update(docRef, {
          value == 1 ? 'upvotes' : 'downvotes': FieldValue.increment(1),
        });
      } else {
        // Flipping from one vote to the other.
        transaction.update(docRef, {
          'upvotes': FieldValue.increment(value == 1 ? 1 : -1),
          'downvotes': FieldValue.increment(value == 1 ? -1 : 1),
        });
      }
    });
  }

  /// Adds a comment to a ride.
  Future<String> addComment({
    required String rideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String text,
  }) async {
    final commentRef = _firestore
        .collection('rides')
        .doc(rideId)
        .collection('comments')
        .doc();

    final comment = {
      'id': commentRef.id,
      'rideId': rideId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    };

    await commentRef.set(comment);
    await _firestore.collection('rides').doc(rideId).update({
      'comments': FieldValue.increment(1),
    });

    return commentRef.id;
  }

  /// Gets comments for a ride.
  Future<List<RideCommentEntity>> getComments(String rideId) async {
    final querySnapshot = await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) {
          final data = doc.data();
          return RideCommentEntity(
            id: doc.id,
            rideId: rideId,
            userId: data['userId'],
            userName: data['userName'],
            userPhotoUrl: data['userPhotoUrl'],
            text: data['text'],
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            updatedAt: data['updatedAt'] != null
                ? (data['updatedAt'] as Timestamp).toDate()
                : null,
          );
        })
        .toList();
  }

  /// Deletes a shared ride.
  Future<void> deleteSharedRide(String rideId) async {
    final docRef = _firestore.collection('rides').doc(rideId);

    // Delete all comments and likes
    final comments =
        await docRef.collection('comments').get();
    for (final comment in comments.docs) {
      await comment.reference.delete();
    }

    final likes = await docRef.collection('likes').get();
    for (final like in likes.docs) {
      await like.reference.delete();
    }

    // Delete the ride
    await docRef.delete();
  }
}
