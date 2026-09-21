import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/cloudinary_upload_service.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/utilities/privacy_zone_clipper.dart';
import '../models/ride_share_model.dart';
import 'follow_repository.dart';
import '../../domain/utilities/privacy_zone_salt.dart';

class RideShareRepository {
  static final RideShareRepository _instance = RideShareRepository._internal();

  factory RideShareRepository() => _instance;

  RideShareRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryUploadService _uploadService = CloudinaryUploadService();
  final FollowRepository _followRepository = FollowRepository();
  final PrivacyZoneSalt _privacySalt = PrivacyZoneSalt();

  /// Uploads a rider-taken ride/bike photo (via Cloudinary — see
  /// [CloudinaryUploadService]) and returns its public URL.
  ///
  /// One call per photo: a ride can carry up to [kMaxRidePhotos], and the
  /// composer uploads them through this same path so multi-photo shares use
  /// no new storage path or credentials.
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
    List<String> photoUrls = const [],
    String? routeId,
    String? caption,
    int? hardBrakeCount,
    int? rapidAccelCount,
    int? highJerkCount,
  }) async {
    // Apply privacy-zone clipping (drops every point within the rider's
    // 200-350 m jittered radius of either end, to hide
    // home/work). On a short or near-home ride the clip can consume the whole
    // track — that must NOT block sharing (this was the "share throws an
    // error" bug). Instead we share with NO route line at all, which is the
    // privacy-safe outcome anyway: the ride still posts, the feed card just
    // shows stats without a map trace.
    final clippedPolyline = PrivacyZoneClipper.clipPolyline(
      polyline,
      seed: await _privacySalt.forUid(userId),
    );

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
      comments: 0,
      createdAt: DateTime.now(),
      audience: audience,
      allowedUserIds: allowedUserIds,
      routeId: routeId,
      // Re-normalized here rather than trusted from the caller: the cap is a
      // data invariant of a shared ride, not a UI rule, so it holds even if a
      // future caller skips the composer.
      photoUrls: normalizeRidePhotoUrls(photoUrls),
      caption: caption,
      hardBrakeCount: hardBrakeCount,
      rapidAccelCount: rapidAccelCount,
      highJerkCount: highJerkCount,
    );

    final docRef = _firestore.collection('rides').doc(rideId);
    final existing = await docRef.get();

    final data = sharedRide.toFirestore();
    if (existing.exists) {
      // Don't wipe engagement accumulated since the ride was first shared.
      data.remove('comments');
      data.remove('upvotes');
      data.remove('downvotes');
    }
    await docRef.set(data, SetOptions(merge: true));

    return rideId;
  }

  /// Patches a previously shared ride's bike name/type after the rider
  /// corrects which bike the ride was actually on (see `ChangeBikeControl`
  /// and `RideAttribution.confirm`). The share is a denormalized snapshot
  /// taken at share time — without this, a bike correction would silently
  /// stop at the local ride row, leaving an already-posted card showing the
  /// wrong bike forever.
  ///
  /// `update()` throwing `not-found` just means this ride was never shared,
  /// which is the common case, not an error worth surfacing to the rider.
  Future<void> updateSharedRideBikeInfo(
    String rideId, {
    required String bikeId,
    required String bikeName,
    required String bikeType,
  }) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'bikeId': bikeId,
        'bikeName': bikeName,
        'bikeType': bikeType,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      rethrow;
    }
  }

  /// Gets a shared ride by ID.
  Future<SharedRideEntity?> getSharedRide(String rideId) async {
    final doc = await _firestore.collection('rides').doc(rideId).get();
    if (!doc.exists || doc.data() == null) return null;

    final model = RideShareModel.fromFirestore(
      doc.data()!,
      doc.id,
    );
    final hydrated = await _hydrate([model.toEntity()]);
    return hydrated.firstOrNull;
  }

  /// Public rides (for discovery). Lines up with the `audience == 'public'`
  /// clause of `rideVisibleTo()` in firestore.rules.
  /// [before] is a cursor: pass the `createdAt` of the oldest ride already
  /// shown to get the next page. Without it the feed was capped at one page
  /// forever — three 20-document queries merged client-side, no cursor, no
  /// "load more", so the social half of the app simply ended at ~60 posts
  /// (issues §83.20).
  Future<List<SharedRideEntity>> getPublicRides({
    int limit = 20,
    DateTime? before,
    bool hydrateVotes = true,
  }) async {
    var q = _firestore
        .collection('rides')
        .where('audience', isEqualTo: 'public')
        .orderBy('createdAt', descending: true);
    if (before != null) q = q.startAfter([Timestamp.fromDate(before)]);
    final entities = _toEntities(await q.limit(limit).get());
    if (!hydrateVotes) return entities;
    return _hydrate(entities);
  }

  /// Public rides authored by [uids] — the real backing query for the
  /// "Following" chip.
  ///
  /// That chip used to filter the already-fetched 20-ride public page against
  /// the follow graph on the client, which meant a rider following 30 people
  /// whose posts weren't in the 20 most recent public rides saw an EMPTY
  /// "Following" feed while those 30 people were actively posting (§83.20).
  ///
  /// `whereIn` caps at 30 values, so the follow list is chunked and the chunks
  /// merged. Each chunk still carries `audience == 'public'`, which is what
  /// lets firestore.rules' `rideVisibleTo` prove the query — see
  /// [getSharedToMe] for the same constraint spelled out.
  Future<List<SharedRideEntity>> getRidesByAuthors(
    Iterable<String> uids, {
    int limit = 20,
    DateTime? before,
    bool hydrateVotes = true,
  }) async {
    final ids = uids.toList();
    if (ids.isEmpty) return const [];

    const chunkSize = 30;
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, min(i + chunkSize, ids.length));
      var q = _firestore
          .collection('rides')
          .where('userId', whereIn: chunk)
          .where('audience', isEqualTo: 'public')
          .orderBy('createdAt', descending: true);
      if (before != null) q = q.startAfter([Timestamp.fromDate(before)]);
      futures.add(q.limit(limit).get());
    }

    final snaps = await Future.wait(futures);
    final merged = [for (final snap in snaps) ..._toEntities(snap)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final page = merged.take(limit).toList();
    if (!hydrateVotes) return page;
    return _hydrate(page);
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
  Future<List<SharedRideEntity>> getSharedToMe(
    String uid, {
    int limit = 20,
    DateTime? before,
    bool hydrateVotes = true,
  }) async {
    var q = _firestore
        .collection('rides')
        .where('allowedUserIds', arrayContains: uid)
        .where('audience', whereIn: ['followers', 'mutual']).orderBy(
            'createdAt',
            descending: true);
    if (before != null) q = q.startAfter([Timestamp.fromDate(before)]);
    final entities = _toEntities(await q.limit(limit).get());
    if (!hydrateVotes) return entities;
    return _hydrate(entities);
  }

  /// The signed-in rider's own shared rides, regardless of audience. Lines
  /// up with the `userId == me` (always-visible-to-owner) clause.
  Future<List<SharedRideEntity>> getMyRides(
    String uid, {
    int limit = 20,
    DateTime? before,
    bool hydrateVotes = true,
  }) async {
    var q = _firestore
        .collection('rides')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
    if (before != null) q = q.startAfter([Timestamp.fromDate(before)]);
    final entities = _toEntities(await q.limit(limit).get());
    if (!hydrateVotes) return entities;
    return _hydrate(entities);
  }

  List<SharedRideEntity> _toEntities(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map((doc) =>
            RideShareModel.fromFirestore(doc.data(), doc.id).toEntity())
        .toList();
  }

  /// Hydrates the signed-in rider's vote state onto each ride — an
  /// entity-only field never stored on the ride doc itself.
  ///
  /// One `get()` per ride. That is a real cost (issues §83.20): the feed fans
  /// out to four queries whose results overlap heavily, so hydrating inside
  /// each query meant the same ride's vote was fetched up to four times per
  /// page. The `hydrateVotes: false` flag lets the feed opt out and call
  /// [hydrateVotesFor] ONCE on the
  /// merged, de-duplicated page instead — see `RideFeedNotifier._fetchPage`.
  ///
  /// Reducing it below one-read-per-ride needs a `collectionGroup('votes')`
  /// query, which in turn needs a `uid` field on each vote document (the uid
  /// is currently only the document id, which a collection-group query can't
  /// filter on), a collection-group read rule, and a backfill of existing
  /// vote docs. Left for a pass that can run and verify that migration.
  Future<List<SharedRideEntity>> _hydrate(
      List<SharedRideEntity> entities) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || entities.isEmpty) return entities;

    final votes = await Future.wait(
        entities.map((ride) => getMyVote(ride.id, currentUserId)));

    return [
      for (var i = 0; i < entities.length; i++)
        entities[i].copyWith(myVote: votes[i]),
    ];
  }

  /// Public entry point for the merged-page hydration described on [_hydrate].
  Future<List<SharedRideEntity>> hydrateVotesFor(
          List<SharedRideEntity> rides) =>
      _hydrate(rides);

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
    final rideRef = _firestore.collection('rides').doc(rideId);
    final commentRef = rideRef.collection('comments').doc();

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

    // Both writes go in ONE transaction, and the bump carries the new
    // comment's id, so firestore.rules can require that the `comments` tally
    // only moves when a matching comment doc is actually created in the same
    // commit (issues §24.7). Two separate calls, as this used to do,
    // gave the rule nothing to check the bump against.
    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, comment);
      transaction.update(rideRef, {
        'comments': FieldValue.increment(1),
        'lastCommentId': commentRef.id,
      });
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

    return querySnapshot.docs.map((doc) {
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
    }).toList();
  }

  /// Deletes a shared ride.
  Future<void> deleteSharedRide(String rideId) async {
    final docRef = _firestore.collection('rides').doc(rideId);

    // Fetch both subcollections concurrently, then fire every delete at
    // once rather than awaiting them one at a time — a popular ride with
    // many comments/votes used to stall proportionally to that count.
    final commentsFuture = docRef.collection('comments').get();
    // `likes` is a retired engagement model (issues_fixed.md §81); legacy
    // docs are still swept up here so a delete leaves nothing behind.
    final likesFuture = docRef.collection('likes').get();
    final comments = await commentsFuture;
    final likes = await likesFuture;
    await Future.wait([
      for (final comment in comments.docs) comment.reference.delete(),
      for (final like in likes.docs) like.reference.delete(),
    ]);

    // Delete the ride
    await docRef.delete();
  }
}
