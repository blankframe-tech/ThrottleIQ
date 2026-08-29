import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../poi_directory/data/repositories/place_repository.dart';
import '../../poi_directory/domain/entities/place_entity.dart';
import 'ride_recording_provider.dart';

final liveRidePlacesProvider = StateNotifierProvider<LiveRidePlacesNotifier, List<PlaceEntity>>((ref) {
  return LiveRidePlacesNotifier(ref);
});

class LiveRidePlacesNotifier extends StateNotifier<List<PlaceEntity>> {
  final Ref _ref;
  final PlaceRepository _placeRepository = PlaceRepository();
  LatLng? _lastFetchLocation;

  LiveRidePlacesNotifier(this._ref) : super([]) {
    _ref.listen(rideRecordingProvider.select((s) => s.currentPosition), (previous, current) {
      if (current != null) {
        _checkAndFetch(current);
      }
    }, fireImmediately: true);
  }

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
      if (distance > 5000) { // 5km
        shouldFetch = true;
      }
    }

    if (shouldFetch) {
      _lastFetchLocation = current;
      try {
        final places = await _placeRepository.getNearbyPlaces(
          latitude: current.latitude,
          longitude: current.longitude,
          radiusKm: 25, // 25km radius
          category: null,
        );
        if (mounted) {
          state = places;
        }
      } catch (e) {
        // Silently ignore or log
      }
    }
  }
}
