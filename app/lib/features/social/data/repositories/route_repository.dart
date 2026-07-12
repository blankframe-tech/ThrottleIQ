import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/route_entity.dart';
import '../models/route_model.dart';

class RouteRepository {
  static final RouteRepository _instance = RouteRepository._internal();

  factory RouteRepository() => _instance;

  RouteRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a new route from a completed ride.
  Future<String> saveRoute({
    required String userId,
    required String name,
    String? description,
    required double distanceKm,
    required List<LatLng> polyline,
    String? mapSnapshotUrl,
  }) async {
    final routeRef = _firestore.collection('users').doc(userId).collection('routes').doc();

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
        .map((doc) =>
            RouteModel.fromFirestore(doc.data(), doc.id).toEntity())
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
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .doc(routeId)
        .update({'isPublic': true});
  }

  /// Updates the times ridden counter.
  Future<void> incrementTimesRidden(String userId, String routeId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('routes')
        .doc(routeId)
        .update({
      'timesRidden': FieldValue.increment(1),
    });
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
