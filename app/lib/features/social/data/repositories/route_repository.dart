import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/route_entity.dart';
import '../../domain/utilities/privacy_zone_clipper.dart';
import '../models/route_model.dart';
import '../../domain/utilities/privacy_zone_salt.dart';

class RouteRepository {
  static final RouteRepository _instance = RouteRepository._internal();

  factory RouteRepository() => _instance;

  RouteRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PrivacyZoneSalt _privacySalt = PrivacyZoneSalt();

  /// Saves a new route from a completed ride.
  ///
  /// Stores the full-fidelity trail — routes are private by default
  /// (`isPublic: false`) and "Only you can see this route" is the promise the
  /// save screen makes for that state, so a personal route deliberately keeps
  /// its real endpoints. Privacy-zone clipping happens in [setPublic], at the
  /// moment a route actually becomes readable by anyone else — see that
  /// method's doc comment (issues §24.3).
  Future<String> saveRoute({
    required String userId,
    required String name,
    String? description,
    required double distanceKm,
    required List<LatLng> polyline,
    String? mapSnapshotUrl,
  }) async {
    final routeRef =
        _firestore.collection('users').doc(userId).collection('routes').doc();

    final route = RouteModel(
      id: routeRef.id,
      userId: userId,
      name: name,
      description: description,
      distanceKm: distanceKm,
      polyline: polyline,
      mapSnapshotUrl: mapSnapshotUrl,
      timesRidden: 1,
      createdAt: DateTime.now(),
      isPublic: false,
      sharedWithUserIds: [],
    );

    await routeRef.set(route.toFirestore());
    return routeRef.id;
  }

  /// Gets a route by ID.
  Future<RouteEntity?> getRoute({
    required String userId,
    required String routeId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .doc(routeId)
        .get();

    if (!doc.exists) return null;

    final model = RouteModel.fromFirestore(doc.data()!, doc.id);
    return model.toEntity();
  }

  /// Gets all routes for a user.
  Future<List<RouteEntity>> getUserRoutes(String userId) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => RouteModel.fromFirestore(doc.data(), doc.id).toEntity())
        .toList();
  }

  /// Gets public routes (for discovery).
  Future<List<RouteEntity>> getPublicRoutes({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collectionGroup('routes')
        .where('isPublic', isEqualTo: true)
        .orderBy('timesRidden', descending: true)
        .limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) =>
            RouteModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)
                .toEntity())
        .toList();
  }

  /// Shares a route with specific users.
  Future<void> shareRoute({
    required String userId,
    required String routeId,
    required List<String> userIds,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .doc(routeId)
        .update({
      'sharedWithUserIds': FieldValue.arrayUnion(userIds),
    });
  }

  /// Makes a route public.
  Future<void> makePublic(String userId, String routeId) async {
    await setPublic(userId, routeId, true);
  }

  /// Flips a route between public (discoverable by every rider) and private
  /// (owner-only). [makePublic] is the one-way shorthand kept for callers that
  /// only ever publish.
  ///
  /// Going public permanently clips the stored polyline (the issues log
  /// §24.3) — strips ~200m off each end, same as
  /// [RideShareRepository.shareRide] does for shared rides. Route *sharing*
  /// always did this; route *publishing* stored the raw trail verbatim, so
  /// flipping this switch used to hand every authenticated rider (via the
  /// `collectionGroup('routes')` rule) a polyline starting from the owner's
  /// driveway. The clip overwrites the stored trail rather than living
  /// alongside a separate "public copy" field — once a route has been public,
  /// its trail is treated as exposed for good, even if it's later set back to
  /// private, the same way a shared ride's clipped copy is never restored.
  /// A short or near-home route can clip down to nothing; that's the
  /// privacy-safe outcome, not an error — the route stays public, just
  /// without a line to draw. Turning a route private does NOT need a read
  /// first — it never touches the polyline.
  Future<void> setPublic(String userId, String routeId, bool isPublic) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .doc(routeId);

    if (!isPublic) {
      await docRef.update({'isPublic': false});
      return;
    }

    final snapshot = await docRef.get();
    final data = snapshot.data();
    final rawPolyline = data == null
        ? const <LatLng>[]
        : RouteModel.fromFirestore(data, routeId).polyline;
    final clipped = PrivacyZoneClipper.clipPolyline(
      rawPolyline,
      seed: await _privacySalt.forUid(userId),
    );

    await docRef.update({
      'isPublic': true,
      'polyline': clipped
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
    });
  }

  /// Records that [userId] has just finished riding their own route
  /// [routeId] (issues §85).
  ///
  /// This existed from the start and was never called from anywhere, so
  /// `timesRidden` sat at the 1 [saveRoute] writes and "ridden 1×" was the
  /// same on every route forever. The caller is `ActiveRideScreen._stopRide`,
  /// on *completion* — not on start, which would count routes a rider opened
  /// and abandoned.
  ///
  /// `FieldValue.increment` rather than read-modify-write, so two phones
  /// finishing the same route at once both count. Ownership needs no branch:
  /// `users/{uid}/routes/{id}` is owner-only write in `firestore.rules` and
  /// the document does not exist under anyone else's uid, so following a
  /// *discovered* route fails and is swallowed. The data model is the check.
  ///
  /// Best-effort, and deliberately **not** put through the outbox. Each
  /// outboxed operation costs a new op type in the dispatcher and the DAO, and
  /// this is a cosmetic counter on a route list — losing a bump because the
  /// rider ended a ride in a basement is not worth that. If it ever becomes
  /// load-bearing (ranking Discover by it, say), this is the line that moves.
  Future<void> incrementTimesRidden(String userId, String routeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('routes')
          .doc(routeId)
          .update({
        'timesRidden': FieldValue.increment(1),
      });
    } catch (e) {
      // Not-found (a discovered route), permission-denied, or plain offline.
      // None of these should surface to a rider who just finished a ride.
      debugPrint('[RouteRepository] timesRidden bump skipped for $routeId: $e');
    }
  }

  /// Deletes a route.
  Future<void> deleteRoute(String userId, String routeId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .doc(routeId)
        .delete();
  }

  /// Updates route details.
  Future<void> updateRoute({
    required String userId,
    required String routeId,
    String? name,
    String? description,
    String? mapSnapshotUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (mapSnapshotUrl != null) updates['mapSnapshotUrl'] = mapSnapshotUrl;

    if (updates.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('routes')
          .doc(routeId)
          .update(updates);
    }
  }
}
