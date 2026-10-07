import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/place_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/services/overpass_service.dart';
import '../../data/utils/geohash_utils.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/places_query.dart';

final _placeRepository = PlaceRepository();
final _reviewRepository = ReviewRepository();
final _overpassService = OverpassService();

/// Why [currentPositionProvider] couldn't produce a fix — typed, so the
/// Places screen can offer the one button that actually fixes each case
/// (ask again / open app settings / open location settings) instead of
/// pattern-matching message text.
enum PlaceLocationProblem { permissionDenied, permissionDeniedForever, serviceDisabled }

class PlaceLocationException implements Exception {
  final PlaceLocationProblem problem;
  const PlaceLocationException(this.problem);

  /// English diagnostics, worded so the shared `isLocationServicesError` /
  /// `isLocationPermissionError` helpers in firebase_error_mapper.dart still
  /// recognise them for any screen that hasn't moved to [problem].
  @override
  String toString() => switch (problem) {
        PlaceLocationProblem.permissionDenied =>
          'Location permission denied. It is needed for this feature.',
        PlaceLocationProblem.permissionDeniedForever =>
          'Location permission permanently denied. Grant it in Settings → ThrottleIQ.',
        PlaceLocationProblem.serviceDisabled =>
          'Location services are disabled. Enable GPS in your device settings.',
      };
}

/// Current device position, fetched once per provider lifetime. Mirrors the
/// permission-check flow in `RideRecordingNotifier._requestPermissions`
/// (`ride_recording_provider.dart`), but as a single point-in-time read
/// (`getCurrentPosition`) rather than a continuous stream — the Places tab
/// and the add-place form only need one fix, not live tracking.
///
/// Fails with a [PlaceLocationException]. The service-disabled message used
/// to read "Location is turned off", which `isLocationServicesError` never
/// matched, so a rider with GPS off got the generic "couldn't load" card and
/// no "Turn on location" button.
final currentPositionProvider = FutureProvider<Position>((ref) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const PlaceLocationException(PlaceLocationProblem.permissionDeniedForever);
  }
  if (permission == LocationPermission.denied) {
    throw const PlaceLocationException(PlaceLocationProblem.permissionDenied);
  }

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const PlaceLocationException(PlaceLocationProblem.serviceDisabled);
  }

  // issues §101.P6: with no time limit a poor fix (indoors, cold GPS)
  // left the Places spinner up forever. On timeout use the last known
  // fix; only a device with no fix at all surfaces the error.
  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: currentPositionTimeLimit,
    );
  } on TimeoutException {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown == null) rethrow;
    return lastKnown;
  }
});

/// How long [currentPositionProvider] waits for a fresh fix.
const currentPositionTimeLimit = Duration(seconds: 15);

/// Every nearby place within [radiusKm] (a [placesRadiusOptionsKm] value),
/// all categories, safety points included. The Places hub filters by
/// category, search text and tags client-side (`applyPlacesQuery`) and pulls
/// the cameras/checkposts out for the Highway Radar, so one fetch per radius
/// serves the chips, the list, the map and the radar together: switching a
/// chip costs no reads, only changing the radius refetches.
///
/// IMPORTANT: a mutation that changes a place's rating or adds a place must
/// invalidate the *whole family* — `ref.invalidate(nearbyPlacesProvider)`
/// with no argument — so no other radius keeps showing the stale copy.
final nearbyPlacesProvider =
    FutureProvider.family<List<PlaceEntity>, double>((ref, radiusKm) async {
  final position = await ref.watch(currentPositionProvider.future);
  return _placeRepository.getNearbyPlaces(
    latitude: position.latitude,
    longitude: position.longitude,
    radiusKm: radiusKm,
  );
});

/// A single place's current data — used by the detail screen's header (name,
/// category, address, rating). Backed by `streamPlace` (rather than the
/// one-shot `getPlace`) so the rating aggregate updates live for every
/// viewer when *any* user submits a review, not just the client that
/// submitted it.
///
/// autoDispose (issues §90.A-LOW): each place opened used to leave its doc
/// listener running for the rest of the session.
final placeDetailProvider =
    StreamProvider.autoDispose.family<PlaceEntity?, String>((ref, placeId) {
  return _placeRepository.streamPlace(placeId);
});

/// Live reviews for a place. Uses `streamReviewsForPlace` (rather than the
/// one-shot `getReviewsForPlace`) so a review submitted from this same
/// screen — or by another rider — appears without an explicit refresh.
///
/// autoDispose for the same reason as [placeDetailProvider].
final reviewsForPlaceProvider =
    StreamProvider.autoDispose.family<List<ReviewEntity>, String>((ref, placeId) {
  return _reviewRepository.streamReviewsForPlace(placeId);
});

/// Places the signed-in rider added themselves ("My places", reached from
/// the garage header's user menu and the Places hub's Saved tab).
final myPlacesProvider = FutureProvider<List<PlaceEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return [];
  return _placeRepository.getPlacesByOwner(uid);
});

/// Largest radius sent to Overpass. A 50 km query is slow and heavy on a
/// volunteer-run server, and the import is a one-off seeding of the area,
/// not a mirror of it.
const double osmImportMaxRadiusKm = placesDefaultRadiusKm;

/// Pulls nearby fuel/parts/garage POIs from OpenStreetMap's Overpass API and
/// imports any not already known (by `osmId`), then invalidates the whole
/// `nearbyPlacesProvider` family so the Places tab picks them up — mirrors
/// the stale-cache discipline documented on that provider above. Only ever
/// called from an explicit, explained "Scan OpenStreetMap" tap (the empty
/// state or the overflow menu in `places_list_screen.dart`): Overpass is a
/// free, rate-limited public service, not something to hit automatically on
/// every tab open. Searches [radiusKm] capped at [osmImportMaxRadiusKm].
/// Returns how many new places were added.
Future<int> importNearbyOsmPlaces(
  WidgetRef ref, {
  double radiusKm = placesDefaultRadiusKm,
}) async {
  final uid = ref.read(currentUserProvider)?.uid;
  if (uid == null) return 0;

  final position = await ref.read(currentPositionProvider.future);
  final candidates = await _overpassService.fetchNearby(
    latitude: position.latitude,
    longitude: position.longitude,
    radiusMeters:
        (radiusKm > osmImportMaxRadiusKm ? osmImportMaxRadiusKm : radiusKm) * 1000,
  );
  if (candidates.isEmpty) return 0;

  final existingOsmIds =
      await _placeRepository.getExistingOsmIds(candidates.map((c) => c.osmId).toList());
  final newCandidates = candidates.where((c) => !existingOsmIds.contains(c.osmId)).toList();

  // One batched write per 400 places (ids `osm_<type>_<id>`) instead of an
  // awaited add() per place.
  await _placeRepository.addPlacesBatched([
    for (final candidate in newCandidates)
      PlaceEntity(
        id: '', // Ignored on write; the repository picks `osm_...` ids.
        name: candidate.name,
        category: candidate.category,
        latitude: candidate.latitude,
        longitude: candidate.longitude,
        geohash: GeohashUtils.encode(candidate.latitude, candidate.longitude),
        address: candidate.address,
        phone: candidate.phone,
        createdBy: uid,
        createdAt: DateTime.now(),
        osmId: candidate.osmId,
      ),
  ]);

  if (newCandidates.isNotEmpty) {
    ref.invalidate(nearbyPlacesProvider);
  }
  return newCandidates.length;
}
