import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/utilities/privacy_zone_clipper.dart';
import '../models/ride_share_model.dart';

class RideShareRepository {
  static final RideShareRepository _instance =
      RideShareRepository._internal();

  factory RideShareRepository() => _instance;

  RideShareRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Shares a ride to friends/public and applies privacy zones.
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
    required bool isPrivate,
    required List<String> allowedUserIds,
    String? routeId,
  }) async {
    // Apply privacy zone clipping
    final clippedPolyline = PrivacyZoneClipper.clipPolyline(polyline);

    if (clippedPolyline.isEmpty) {
      throw Exception('Polyline too short after privacy zone clipping');
    }

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
      isPrivate: isPrivate,
      allowedUserIds: allowedUserIds,
      routeId: routeId,
    );

    final docRef = _firestore.collection('rides').doc(rideId);
    final existing = await docRef.get();

    final data = sharedRide.toFirestore();
    if (existing.exists) {
      // Don't wipe engagement accumulated since the ride was first shared.
      data.remove('likes');
      data.remove('comments');
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

  /// Gets feed of shared rides from friends (paginated).
  Future<List<SharedRideEntity>> getFriendsFeed({
    required String currentUserId,
    required List<String> friendIds,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('rides')
        .where('userId', whereIn: friendIds)
        .where('isPrivate', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) =>
            RideShareModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)
                .toEntity())
        .toList();
  }

  /// Gets all public rides (for discovery).
  Future<List<SharedRideEntity>> getPublicRides({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('rides')
        .where('isPrivate', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.get();
    final entities = querySnapshot.docs
        .map((doc) =>
            RideShareModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)
                .toEntity())
        .toList();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return entities;

    // Per-ride existence check for the current user's like doc, in parallel.
    final likedFlags = await Future.wait(entities.map((ride) => _firestore
        .collection('rides')
        .doc(ride.id)
        .collection('likes')
        .doc(currentUserId)
        .get()
        .then((doc) => doc.exists)));

    return [
      for (var i = 0; i < entities.length; i++)
        entities[i].copyWith(isLikedByCurrentUser: likedFlags[i]),
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

  /// Updates ride visibility.
  Future<void> updateRideVisibility({
    required String rideId,
    required bool isPrivate,
    required List<String> allowedUserIds,
  }) async {
    await _firestore.collection('rides').doc(rideId).update({
      'isPrivate': isPrivate,
      'allowedUserIds': allowedUserIds,
    });
  }
}
