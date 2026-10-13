import 'package:equatable/equatable.dart';

import 'entities/place_entity.dart';
import 'places_query.dart';

/// Speed cameras and police checkposts around the rider, kept apart from
/// the list of stops (a checkpost is something to know about, not somewhere
/// to go). Both lists are nearest-first.
class HighwayRadar extends Equatable {
  final List<PlaceHit> cameras;
  final List<PlaceHit> police;

  const HighwayRadar({this.cameras = const [], this.police = const []});

  static const empty = HighwayRadar();

  int get total => cameras.length + police.length;
  bool get isEmpty => total == 0;

  /// Every point, nearest first — what the map highlights.
  List<PlaceHit> get all {
    final merged = [...cameras, ...police];
    merged.sort(_nearestFirst);
    return merged;
  }

  /// The closest point of either kind, or null if there is none (or no
  /// distance is known).
  PlaceHit? get nearest {
    final withDistance = all.where((h) => h.distanceKm != null);
    return withDistance.isEmpty ? null : withDistance.first;
  }

  @override
  List<Object?> get props => [cameras, police];
}

int _nearestFirst(PlaceHit a, PlaceHit b) {
  final da = a.distanceKm, db = b.distanceKm;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}

/// Picks the safety points out of [places] that lie within [radiusKm] of the
/// rider. With no fix ([originLat]/[originLng] null) nothing can be said to
/// be "within" anything, so every safety point in the batch is reported —
/// the batch was already fetched around the rider's last known position.
HighwayRadar computeHighwayRadar(
  Iterable<PlaceEntity> places, {
  double? originLat,
  double? originLng,
  required double radiusKm,
}) {
  final cameras = <PlaceHit>[];
  final police = <PlaceHit>[];
  for (final place in places) {
    if (!place.category.isSafetyPoint) continue;
    final hit = toHit(place, originLat: originLat, originLng: originLng);
    final distance = hit.distanceKm;
    if (distance != null && distance > radiusKm) continue;
    (place.category == PlaceCategory.aiCamera ? cameras : police).add(hit);
  }
  cameras.sort(_nearestFirst);
  police.sort(_nearestFirst);
  return HighwayRadar(cameras: cameras, police: police);
}
