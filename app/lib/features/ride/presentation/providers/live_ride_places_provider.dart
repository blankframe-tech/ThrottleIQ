import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../poi_directory/data/ride_places_cache.dart';
import '../../../poi_directory/domain/entities/place_entity.dart';
import '../../../poi_directory/presentation/providers/places_provider.dart';
import 'ride_recording_provider.dart';

final liveRidePlacesProvider =
    StateNotifierProvider<LiveRidePlacesNotifier, List<PlaceEntity>>((ref) {
  return LiveRidePlacesNotifier(ref);
});

class LiveRidePlacesNotifier extends StateNotifier<List<PlaceEntity>> {
  final Ref _ref;
  late final RidePlacesCache _cache = _ref.read(placesCacheProvider);
  LatLng? _lastFetchLocation;
  // Refreshes run one at a time; they share the cache file.
  Future<void> _refreshing = Future.value();

  /// Places shown within this distance, refreshed every [refetchMeters]
  /// (issues §104.1: was 25 km, every 5 km, straight from Firestore).
  static const double radiusKm = 10;
  static const double refetchMeters = 5000;

  LiveRidePlacesNotifier(this._ref) : super([]) {
    _ref.listen(rideRecordingProvider.select((s) => s.currentPosition),
        (previous, current) {
      if (current != null) {
        _checkAndFetch(current);
      }
    }, fireImmediately: true);
  }

  /// Shows a place the rider just reported without waiting for the next
  /// 5 km refetch.
  void add(PlaceEntity place) => state = [...state, place];

  Future<void> _checkAndFetch(LatLng current) async {
    // Fetch if we haven't fetched yet, or if we moved more than 5km
    bool shouldFetch = false;
    if (_lastFetchLocation == null) {
      shouldFetch = true;
    } else {
      final distance = Geolocator.distanceBetween(
        _lastFetchLocation!.latitude,
        _lastFetchLocation!.longitude,
        current.latitude,
        current.longitude,
      );
      if (distance > refetchMeters) {
        shouldFetch = true;
      }
    }

    if (shouldFetch) {
      _lastFetchLocation = current;
      _refreshing = _refreshing.then((_) => _fetch(current));
    }
  }

  Future<void> _fetch(LatLng at) async {
    try {
      // The cached places go up at once; the pull then fills in changes.
      _show(await _cache.nearby(at.latitude, at.longitude, radiusKm));
      await _cache.refresh(at.latitude, at.longitude, radiusKm);
    } catch (e) {
      // Offline or a failed pull: the cached places stay up.
      debugPrint('[LiveRidePlaces] refresh failed: $e');
    }
    _show(await _cache.nearby(at.latitude, at.longitude, radiusKm));
  }

  void _show(List<PlaceEntity> places) {
    if (mounted) state = places;
  }
}
