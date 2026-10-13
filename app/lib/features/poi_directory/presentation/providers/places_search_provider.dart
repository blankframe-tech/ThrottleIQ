import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/error_reporter.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/highway_radar.dart';
import '../../domain/place_tags.dart';
import '../../domain/places_query.dart';
import 'places_provider.dart';

/// How long typing must pause before the search text is applied. Filtering
/// is client-side and cheap, but re-laying-out the map's markers and the
/// carousel on every keystroke is not.
const Duration placesSearchDebounce = Duration(milliseconds: 300);

/// SharedPreferences key for the rider's chosen radius — the one refinement
/// worth remembering between sessions (a highway tourer wants 50 km every
/// time; a city commuter, 5).
const String placesRadiusPrefKey = 'places_radius_km';

/// The Places hub's live search/filter state. See [PlacesQuery].
class PlacesQueryNotifier extends Notifier<PlacesQuery> {
  Timer? _debounce;

  @override
  PlacesQuery build() {
    ref.onDispose(() => _debounce?.cancel());
    unawaited(_restoreRadius());
    return const PlacesQuery();
  }

  Future<void> _restoreRadius() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(placesRadiusPrefKey);
      if (saved != null && placesRadiusOptionsKm.contains(saved) && saved != state.radiusKm) {
        state = state.copyWith(radiusKm: saved);
      }
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'places: restore radius');
    }
  }

  /// Applies [text] after [placesSearchDebounce] of quiet.
  void setTextDebounced(String text) {
    _debounce?.cancel();
    _debounce = Timer(placesSearchDebounce, () => setText(text));
  }

  /// Applies [text] now (clearing the field, submitting from the keyboard).
  void setText(String text) {
    _debounce?.cancel();
    if (text != state.text) state = state.copyWith(text: text);
  }

  void setCategory(PlaceCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  Future<void> setRadius(double radiusKm) async {
    if (radiusKm == state.radiusKm) return;
    state = state.copyWith(radiusKm: radiusKm);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(placesRadiusPrefKey, radiusKm);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'places: persist radius');
    }
  }

  void setVerifiedOnly(bool value) => state = state.copyWith(verifiedOnly: value);

  void setSort(PlacesSort sort) => state = state.copyWith(sort: sort);

  void toggleTag(PlaceTag tag) {
    final tags = {...state.tags};
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(tags: tags);
  }

  /// Resets the filter sheet's refinements, keeping the search text, the
  /// selected category and the radius (each visible, and undone, on its own).
  void clearRefinements() {
    state = state.copyWith(
      verifiedOnly: false,
      sort: PlacesSort.distance,
      tags: const {},
    );
  }
}

final placesQueryProvider =
    NotifierProvider<PlacesQueryNotifier, PlacesQuery>(PlacesQueryNotifier.new);

/// The fetched batch for the selected radius — the single source the
/// list, the map, the chip counts and the Highway Radar all derive from.
final placesBatchProvider = Provider<AsyncValue<List<PlaceEntity>>>((ref) {
  final radius = ref.watch(placesQueryProvider.select((q) => q.radiusKm));
  return ref.watch(nearbyPlacesProvider(radius));
});

/// Cameras and checkposts within the selected radius.
final highwayRadarProvider = Provider<HighwayRadar>((ref) {
  final places = ref.watch(placesBatchProvider).valueOrNull;
  if (places == null) return HighwayRadar.empty;
  final position = ref.watch(currentPositionProvider).valueOrNull;
  final radius = ref.watch(placesQueryProvider.select((q) => q.radiusKm));
  return computeHighwayRadar(
    places,
    originLat: position?.latitude,
    originLng: position?.longitude,
    radiusKm: radius,
  );
});

enum PlacesViewMode { map, list }

/// Map or list. Not persisted: the map is the hub's front page, and a list a
/// rider flipped to for one search shouldn't become the default forever.
final placesViewModeProvider = StateProvider<PlacesViewMode>((_) => PlacesViewMode.map);

/// Whether the Highway Radar's points are highlighted on the map. The radar
/// banner's tap toggles it.
final radarHighlightProvider = StateProvider<bool>((_) => false);

/// Whether the rider dismissed the radar banner. Per session: a new ride
/// day deserves a fresh warning.
final radarDismissedProvider = StateProvider<bool>((_) => false);

/// The place the map carousel / selected marker is on, by id.
final selectedPlaceIdProvider = StateProvider<String?>((_) => null);
