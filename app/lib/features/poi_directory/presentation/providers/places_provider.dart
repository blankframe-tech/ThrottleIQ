import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/place_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/entities/review_entity.dart';

final _placeRepository = PlaceRepository();
final _reviewRepository = ReviewRepository();

/// Radius used for the nearby-places query. Not user-configurable in this
/// phase — the whole list is client-filtered further by category chips.
const double placesSearchRadiusKm = 25;

/// Current device position, fetched once per provider lifetime. Mirrors the
/// permission-check flow in `RideRecordingNotifier._requestPermissions`
/// (`ride_recording_provider.dart`), but as a single point-in-time read
/// (`getCurrentPosition`) rather than a continuous stream — the Places tab
/// and the add-place form only need one fix, not live tracking.
final currentPositionProvider = FutureProvider<Position>((ref) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Location permission is required to find nearby places.');
  }

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled. Please enable GPS.');
  }

  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
});

/// Nearby places within [placesSearchRadiusKm], optionally filtered by
/// category (`null` = all categories). Keyed by category so switching the
/// filter chip doesn't refetch/discard the other categories' cached results.
///
/// IMPORTANT: because the same place can be cached under both the `null`
/// ("All") key and its own category key, a mutation that changes a place's
/// rating or adds a new place must invalidate the *whole family* —
/// `ref.invalidate(nearbyPlacesProvider)` with no argument — not just the
/// currently-selected category. This is exactly the "stale cached count"
/// class of bug flagged from Phase 2/3's reviews: invalidating only one key
/// would leave the other still showing the old rating/count.
final nearbyPlacesProvider =
    FutureProvider.family<List<PlaceEntity>, PlaceCategory?>((ref, category) async {
  final position = await ref.watch(currentPositionProvider.future);
  return _placeRepository.getNearbyPlaces(
    latitude: position.latitude,
    longitude: position.longitude,
    radiusKm: placesSearchRadiusKm,
    category: category,
  );
});

/// A single place's current data — used by the detail screen's header (name,
/// category, address, rating). Backed by `streamPlace` (rather than the
/// one-shot `getPlace`) so the rating aggregate updates live for every
/// viewer when *any* user submits a review, not just the client that
/// submitted it.
final placeDetailProvider = StreamProvider.family<PlaceEntity?, String>((ref, placeId) {
  return _placeRepository.streamPlace(placeId);
});

/// Live reviews for a place. Uses `streamReviewsForPlace` (rather than the
/// one-shot `getReviewsForPlace`) so a review submitted from this same
/// screen — or by another rider — appears without an explicit refresh.
final reviewsForPlaceProvider =
    StreamProvider.family<List<ReviewEntity>, String>((ref, placeId) {
  return _reviewRepository.streamReviewsForPlace(placeId);
});
