import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/poi_directory/data/models/place_model.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

class PlaceRepository {
  final FirebaseFirestore _firestore;

  PlaceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'places';

  /// Add a new place
  Future<String> addPlace(PlaceEntity place) async {
    final model = PlaceModel.fromEntity(place);
    final docRef = await _firestore.collection(_collection).add(
      model.toFirestore(),
    );
    return docRef.id;
  }

  /// Update a place
  Future<void> updatePlace(String placeId, PlaceEntity place) async {
    final model = PlaceModel.fromEntity(place);
    await _firestore.collection(_collection).doc(placeId).update(
      model.toFirestore(),
    );
  }

  /// Update place verification (admin only)
  Future<void> updateVerification(String placeId, bool verified) async {
    await _firestore.collection(_collection).doc(placeId).update({
      'verified': verified,
    });
  }

  /// Get a place by ID
  Future<PlaceEntity?> getPlace(String placeId) async {
    final doc = await _firestore.collection(_collection).doc(placeId).get();
    if (!doc.exists) return null;
    return PlaceModel.fromFirestore(doc).toEntity();
  }

  /// Get places by category
  Future<List<PlaceEntity>> getPlacesByCategory(PlaceCategory category) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('category', isEqualTo: category.name)
        .get();
    return querySnapshot.docs
        .map((doc) => PlaceModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get places by geohash prefix (for map viewport query)
  Future<List<PlaceEntity>> getPlacesByGeohash(String geohashPrefix) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
        .where('geohash', isLessThan: geohashPrefix + '~')
        .get();
    return querySnapshot.docs
        .map((doc) => PlaceModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get places by multiple geohash prefixes (for complex viewport)
  Future<List<PlaceEntity>> getPlacesByGeohashes(
    List<String> geohashPrefixes,
  ) async {
    final places = <PlaceEntity>[];
    for (final prefix in geohashPrefixes) {
      final result = await getPlacesByGeohash(prefix);
      places.addAll(result);
    }
    // Remove duplicates
    final seen = <String>{};
    return places.where((p) => seen.add(p.id)).toList();
  }

  /// Get all places (with optional category filter)
  Future<List<PlaceEntity>> getAllPlaces({
    PlaceCategory? category,
    bool? verified,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (verified != null) {
      query = query.where('verified', isEqualTo: verified);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => PlaceModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Delete a place
  Future<void> deletePlace(String placeId) async {
    await _firestore.collection(_collection).doc(placeId).delete();
  }

  /// Get nearby places (within radius, sorted by distance)
  Future<List<PlaceEntity>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required double radiusKm,
    PlaceCategory? category,
  }) async {
    // Get all places in the region and filter by distance in memory
    // In production, consider using a proper geo-querying library
    final places = await getAllPlaces(category: category);

    final nearby = <PlaceEntity>[];
    for (final place in places) {
      final distance = _calculateDistance(latitude, longitude, place.latitude, place.longitude);
      if (distance <= radiusKm) {
        nearby.add(place);
      }
    }

    // Sort by distance
    nearby.sort((a, b) {
      final distA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
      final distB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    return nearby;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) {
    return deg * (3.14159265359 / 180);
  }

  /// Search places by name
  Future<List<PlaceEntity>> searchPlacesByName(String query) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + 'z')
        .get();
    return querySnapshot.docs
        .map((doc) => PlaceModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Stream a single place's data (real-time) — mirrors
  /// `ReviewRepository.streamReviewsForPlace` so a place's rating aggregate
  /// updates live for every viewer, not just the client that just submitted
  /// a review.
  Stream<PlaceEntity?> streamPlace(String placeId) {
    return _firestore.collection(_collection).doc(placeId).snapshots().map(
        (doc) => doc.exists ? PlaceModel.fromFirestore(doc).toEntity() : null);
  }

  /// Update place ratings
  Future<void> updatePlaceRating(
    String placeId, {
    required double ratingSum,
    required int ratingCount,
  }) async {
    await _firestore.collection(_collection).doc(placeId).update({
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
    });
  }
}


