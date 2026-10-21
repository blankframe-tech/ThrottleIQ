import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/core/utils/geohash_util.dart';
import 'package:throttleiq/core/services/cloudinary_upload_service.dart';
import 'package:throttleiq/features/poi_directory/data/models/place_model.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/core/cloud/write_ack.dart';

class PlaceRepository {
  final FirebaseFirestore _firestore;
  final CloudinaryUploadService _uploadService;

  PlaceRepository({
    FirebaseFirestore? firestore,
    CloudinaryUploadService? uploadService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uploadService = uploadService ?? CloudinaryUploadService();

  static const String _collection = 'places';

  /// Uploads a rider-taken photo of a place (via Cloudinary — same service
  /// and unsigned preset as `RideShareRepository.uploadRidePhoto`, since
  /// Firebase Storage isn't available on this project's billing plan) and
  /// returns its public URL for [PlaceEntity.photoUrls].
  ///
  /// Foldered per submitter rather than per place: a place has no id until
  /// `addPlace` returns, and the photo has to exist before the document that
  /// references it is written.
  Future<String> uploadPlacePhoto(String uid, File file) {
    return _uploadService.upload(file, folder: 'places/$uid');
  }

  /// Add a new place
  Future<String> addPlace(PlaceEntity place) async {
    final model = PlaceModel.fromEntity(place);
    // doc() + set() rather than add(): same auto id, but known before the
    // ack, so a queued write can still return it.
    final docRef = _firestore.collection(_collection).doc();
    await ackOrQueued(docRef.set(model.toFirestore()));
    return docRef.id;
  }

  /// Firestore caps a batch at 500 writes; stay well under it.
  static const int importBatchSize = 400;

  /// Deterministic doc id for an OSM-imported place, e.g. `node/123` →
  /// `osm_node_123` (a `/` in a doc id would be read as a path separator).
  /// Two imports of the same OSM feature land on the same doc instead of
  /// creating a duplicate.
  static String osmDocId(String osmId) => 'osm_${osmId.replaceAll('/', '_')}';

  /// Adds many places in [importBatchSize]-write batches (the OSM import
  /// used to await one `add()` per place, sequentially). Places with an
  /// `osmId` get [osmDocId]; others get an auto id.
  ///
  /// Callers still filter out already-imported `osmId`s first
  /// ([getExistingOsmIds]): a `set` onto an existing place is an update,
  /// which firestore.rules denies, and one denied write fails its batch.
  Future<void> addPlacesBatched(List<PlaceEntity> places) async {
    final collection = _firestore.collection(_collection);
    for (var i = 0; i < places.length; i += importBatchSize) {
      final chunk = places.sublist(
        i,
        i + importBatchSize > places.length
            ? places.length
            : i + importBatchSize,
      );
      final batch = _firestore.batch();
      for (final place in chunk) {
        final osmId = place.osmId;
        final ref = osmId != null && osmId.isNotEmpty
            ? collection.doc(osmDocId(osmId))
            : collection.doc();
        batch.set(ref, PlaceModel.fromEntity(place).toFirestore());
      }
      await ackOrQueued(batch.commit());
    }
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
        .where('geohash', isLessThan: '$geohashPrefix~')
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

  /// Places the signed-in rider added themselves ("My places").
  Future<List<PlaceEntity>> getPlacesByOwner(String uid) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('createdBy', isEqualTo: uid)
        .get();
    return querySnapshot.docs
        .map((doc) => PlaceModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Which of [osmIds] already exist as places — used by the OSM import
  /// flow to skip re-creating a place it already pulled in. Chunked into
  /// ≤30-id batches since Firestore's `whereIn` caps at 30 values.
  Future<Set<String>> getExistingOsmIds(List<String> osmIds) async {
    if (osmIds.isEmpty) return {};
    final found = <String>{};
    for (var i = 0; i < osmIds.length; i += 30) {
      final chunk =
          osmIds.sublist(i, i + 30 > osmIds.length ? osmIds.length : i + 30);
      final snap = await _firestore
          .collection(_collection)
          .where('osmId', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final id = doc.data()['osmId'] as String?;
        if (id != null) found.add(id);
      }
    }
    return found;
  }

  /// Get nearby places (within radius, sorted by distance).
  ///
  /// This used to read the entire `places` collection and filter in Dart,
  /// so every rider paid for every place in the country on each refresh.
  /// Now it issues one `geohash` range query per cell of
  /// [GeohashUtil.coverCircle] (at most [GeohashUtil.maxCoverCells], in
  /// parallel), dedupes, and applies the exact haversine filter. The
  /// category-filtered case needs the (`category`, `geohash`) composite
  /// index in `firestore.indexes.json`.
  Future<List<PlaceEntity>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required double radiusKm,
    PlaceCategory? category,
    DateTime? now,
    NearbyCellCache? cache,
  }) {
    return nearbyViaGeohashRanges(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      category: category,
      now: now,
      fetchRange: _fetchGeohashRange,
      cache: cache,
    );
  }

  Future<List<PlaceEntity>> _fetchGeohashRange(
    String prefix,
    PlaceCategory? category,
  ) async {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    final snap = await query
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: '$prefix~')
        .get();
    return snap.docs
        .map((doc) => PlaceModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// The query plan behind [getNearbyPlaces], with the Firestore read
  /// injected as [fetchRange] (every place whose geohash starts with the
  /// given prefix) so tests can run it against an in-memory fake. With a
  /// [cache], cells it already holds cost no reads.
  @visibleForTesting
  static Future<List<PlaceEntity>> nearbyViaGeohashRanges({
    required double latitude,
    required double longitude,
    required double radiusKm,
    PlaceCategory? category,
    DateTime? now,
    required Future<List<PlaceEntity>> Function(
      String prefix,
      PlaceCategory? category,
    ) fetchRange,
    NearbyCellCache? cache,
  }) async {
    final currentTime = now ?? DateTime.now();
    final cells = GeohashUtil.coverCircle(latitude, longitude, radiusKm);
    final batches = await Future.wait(cells.map((cell) => cache == null
        ? fetchRange(cell, category)
        : cache.fetch(cell, category, currentTime, fetchRange)));

    final seen = <String>{};
    final withDistance = <(PlaceEntity, double)>[];
    for (final place in batches.expand((batch) => batch)) {
      if (place.isExpiredAt(currentTime)) continue;
      // A place the rider just added has no id yet ('') until the server
      // acks it, so only dedupe real ids.
      if (place.id.isNotEmpty && !seen.add(place.id)) continue;
      final km = haversineMeters(
            latitude,
            longitude,
            place.latitude,
            place.longitude,
          ) /
          1000.0;
      if (km <= radiusKm) withDistance.add((place, km));
    }
    withDistance.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (place, _) in withDistance) place];
  }

  /// Search places by name (prefix match).
  ///
  /// issues §33.12: the upper bound used to be `query + 'z'`, which
  /// only brackets every continuation of [query] when every possible next
  /// character sorts below U+007A — true for plain ASCII, false for this
  /// app's Bengali place names (U+0980–U+09FF), which sort above `'z'` and so
  /// fell outside the range entirely. `''` is the standard Firestore
  /// prefix-query sentinel: a private-use codepoint higher than any realistic
  /// character in a place name, in any script.
  Future<List<PlaceEntity>> searchPlacesByName(String query) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: '$query')
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

/// Results of [PlaceRepository.getNearbyPlaces] kept per geohash cell, so a
/// caller that asks again for an overlapping area reads only the cells it
/// doesn't hold yet (issues §104.1: the live ride used to re-read every
/// place within 25 km after each 5 km moved). Cells expire after [ttl] so
/// places other riders add still show up.
class NearbyCellCache {
  NearbyCellCache({this.ttl = const Duration(hours: 6)});

  final Duration ttl;
  final Map<String, ({DateTime fetchedAt, List<PlaceEntity> places})> _cells =
      {};

  static String _key(String cell, PlaceCategory? category) =>
      '${category?.name ?? '*'}|$cell';

  Future<List<PlaceEntity>> fetch(
    String cell,
    PlaceCategory? category,
    DateTime now,
    Future<List<PlaceEntity>> Function(String, PlaceCategory?) fetchRange,
  ) async {
    final key = _key(cell, category);
    final hit = _cells[key];
    if (hit != null && now.difference(hit.fetchedAt) < ttl) return hit.places;
    final places = await fetchRange(cell, category);
    _cells[key] = (fetchedAt: now, places: places);
    return places;
  }

  /// Puts a place this device just wrote into every cached cell it falls
  /// in, so the next lookup keeps showing it without a re-read.
  void add(PlaceEntity place) {
    for (final key in _cells.keys.toList()) {
      final sep = key.indexOf('|');
      final category = key.substring(0, sep);
      final cell = key.substring(sep + 1);
      if (category != '*' && category != place.category.name) continue;
      final hash = GeohashUtil.encode(place.latitude, place.longitude,
          precision: cell.length);
      if (hash != cell) continue;
      final old = _cells[key]!;
      _cells[key] = (fetchedAt: old.fetchedAt, places: [...old.places, place]);
    }
  }
}
