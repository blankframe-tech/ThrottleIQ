import 'package:equatable/equatable.dart';

import '../../../core/utils/geo_math.dart';
import 'entities/place_entity.dart';
import 'place_tags.dart';

/// Search radii the Places hub offers. 25 km is the old hard-coded value and
/// stays the default; 5 km suits a dense city centre, 50 km a highway tour
/// where the next pump or mechanic really can be that far away.
const List<double> placesRadiusOptionsKm = [5, 15, 25, 50];
const double placesDefaultRadiusKm = 25;

enum PlacesSort { distance, rating }

/// Everything the rider has asked the Places list to narrow down to.
///
/// Pure value — the notifier in `places_search_provider.dart` owns the
/// mutable copy and the debounce; [applyPlacesQuery] does the filtering, so
/// both are unit-testable without widgets or Firestore.
class PlacesQuery extends Equatable {
  final String text;

  /// `null` = all destination categories.
  final PlaceCategory? category;
  final double radiusKm;
  final bool verifiedOnly;
  final PlacesSort sort;

  /// A place must carry *every* selected tag (24/7 *and* 95 octane), which is
  /// what "show me pumps that are open now and have 95" means.
  final Set<PlaceTag> tags;

  const PlacesQuery({
    this.text = '',
    this.category,
    this.radiusKm = placesDefaultRadiusKm,
    this.verifiedOnly = false,
    this.sort = PlacesSort.distance,
    this.tags = const {},
  });

  /// How many sheet-level refinements are active (radius changes count, a
  /// category chip or search text do not — those are visible already). Drives
  /// the badge on the filter button.
  int get activeRefinementCount =>
      (verifiedOnly ? 1 : 0) +
      (sort != PlacesSort.distance ? 1 : 0) +
      (radiusKm != placesDefaultRadiusKm ? 1 : 0) +
      tags.length;

  PlacesQuery copyWith({
    String? text,
    PlaceCategory? category,
    bool clearCategory = false,
    double? radiusKm,
    bool? verifiedOnly,
    PlacesSort? sort,
    Set<PlaceTag>? tags,
  }) {
    return PlacesQuery(
      text: text ?? this.text,
      category: clearCategory ? null : (category ?? this.category),
      radiusKm: radiusKm ?? this.radiusKm,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      sort: sort ?? this.sort,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [text, category, radiusKm, verifiedOnly, sort, tags];
}

/// A place plus its distance from the rider, computed once per list build
/// instead of once per card.
class PlaceHit extends Equatable {
  final PlaceEntity place;

  /// Null when there is no GPS fix (the Saved tab offline, say).
  final double? distanceKm;

  const PlaceHit(this.place, this.distanceKm);

  @override
  List<Object?> get props => [place, distanceKm];
}

/// Rough door-to-door minutes at [kmPerHour] — a city-traffic average, not a
/// routing estimate. Shown with a "~" so nobody mistakes it for one.
int approxRideMinutes(double km, {double kmPerHour = 30}) =>
    (km / kmPerHour * 60).ceil().clamp(1, 24 * 60);

PlaceHit toHit(PlaceEntity place, {double? originLat, double? originLng}) {
  if (originLat == null || originLng == null) return PlaceHit(place, null);
  return PlaceHit(
    place,
    haversineMeters(originLat, originLng, place.latitude, place.longitude) / 1000,
  );
}

String _normalize(String s) => s.toLowerCase().trim();

/// Whether [place] matches every whitespace-separated token of [text] in its
/// name, address, category (English and the rider's language via
/// [categoryLabel]) or tags (via [tagLabel]). Token-AND is what makes
/// "shell mirpur" find the Shell pump in Mirpur rather than every Shell and
/// everything in Mirpur.
bool matchesSearch(
  PlaceEntity place,
  String text, {
  String Function(PlaceCategory)? categoryLabel,
  String Function(PlaceTag)? tagLabel,
}) {
  final tokens = _normalize(text).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  final haystack = _normalize([
    place.name,
    place.address,
    place.category.displayName,
    if (categoryLabel != null) categoryLabel(place.category),
    for (final tag in place.tags) ...[
      tag.name,
      if (tagLabel != null) tagLabel(tag),
    ],
  ].join(' '));
  return tokens.every(haystack.contains);
}

bool _passesRefinements(
  PlaceHit hit,
  PlacesQuery query, {
  String Function(PlaceCategory)? categoryLabel,
  String Function(PlaceTag)? tagLabel,
}) {
  final place = hit.place;
  final distance = hit.distanceKm;
  if (distance != null && distance > query.radiusKm) return false;
  if (query.verifiedOnly && !place.verified) return false;
  if (!place.tags.containsAll(query.tags)) return false;
  return matchesSearch(place, query.text,
      categoryLabel: categoryLabel, tagLabel: tagLabel);
}

/// Filters and sorts [places] for the Places list/map.
///
/// Safety points (cameras, checkposts) never appear here — they belong to
/// the Highway Radar ([computeHighwayRadar]), not the list of stops.
List<PlaceHit> applyPlacesQuery(
  Iterable<PlaceEntity> places,
  PlacesQuery query, {
  double? originLat,
  double? originLng,
  String Function(PlaceCategory)? categoryLabel,
  String Function(PlaceTag)? tagLabel,
}) {
  final hits = <PlaceHit>[
    for (final place in places)
      if (!place.category.isSafetyPoint &&
          (query.category == null || place.category == query.category))
        toHit(place, originLat: originLat, originLng: originLng),
  ].where((hit) => _passesRefinements(hit, query,
      categoryLabel: categoryLabel, tagLabel: tagLabel)).toList();

  int byDistance(PlaceHit a, PlaceHit b) {
    final da = a.distanceKm, db = b.distanceKm;
    if (da == null && db == null) return a.place.name.compareTo(b.place.name);
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  switch (query.sort) {
    case PlacesSort.distance:
      hits.sort(byDistance);
    case PlacesSort.rating:
      hits.sort((a, b) {
        final byRating = b.place.sortRating.compareTo(a.place.sortRating);
        return byRating != 0 ? byRating : byDistance(a, b);
      });
  }
  return hits;
}

/// Per-chip counts for the category ribbon: how many places each chip would
/// show given every *other* active filter (text, radius, tags, verified).
/// The `null` key is the "All" chip.
Map<PlaceCategory?, int> countByCategory(
  Iterable<PlaceEntity> places,
  PlacesQuery query, {
  double? originLat,
  double? originLng,
  String Function(PlaceCategory)? categoryLabel,
  String Function(PlaceTag)? tagLabel,
}) {
  final counts = <PlaceCategory?, int>{
    null: 0,
    for (final c in PlaceCategory.destinations) c: 0,
  };
  final unscoped = query.copyWith(clearCategory: true);
  for (final place in places) {
    if (place.category.isSafetyPoint) continue;
    final hit = toHit(place, originLat: originLat, originLng: originLng);
    if (!_passesRefinements(hit, unscoped,
        categoryLabel: categoryLabel, tagLabel: tagLabel)) {
      continue;
    }
    counts[null] = counts[null]! + 1;
    counts[place.category] = counts[place.category]! + 1;
  }
  return counts;
}
