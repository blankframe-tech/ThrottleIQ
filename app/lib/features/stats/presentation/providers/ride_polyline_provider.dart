import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/database/daos/ride_point_dao.dart';

/// Points to draw for a thumbnail-sized route. A ride records a point every
/// few seconds, so an hour's ride is hundreds of them — far more than a
/// 110 px-tall map can resolve.
const int thumbnailPointBudget = 80;

/// The route polyline for one ride, ready to hand to `RideRouteMap`.
///
/// A `family` provider rather than a per-row `FutureBuilder` because the
/// all-rides list is long and scrolls both ways: a FutureBuilder re-queries
/// SQLite every time a row is scrolled off and back on, and re-runs on every
/// rebuild of the row. Riverpod keys the future by rideId and holds the
/// result, so each ride is read from the database at most once per session
/// and scrolling back up is free.
///
/// Deliberately NOT autoDispose — disposing on scroll-off is exactly the
/// thrash this exists to avoid. The memory that buys is bounded by
/// [thumbnailPointBudget]: whatever the ride's real point count, what we
/// retain is at most 80 LatLngs (~2 KB) per ride.
///
/// The rows themselves are built lazily by `ListView.builder`, so this only
/// ever runs for rides the rider has actually scrolled to.
final ridePolylineProvider =
    FutureProvider.family<List<LatLng>, String>((ref, rideId) async {
  final rows = await RidePointDao().getForRide(rideId);
  final points = <LatLng>[
    for (final r in rows)
      if (r['lat'] is num && r['lng'] is num)
        LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
  ];
  return downsamplePolyline(points, thumbnailPointBudget);
});

/// Evenly thins [points] to at most [budget] entries, always keeping the
/// first and last so the start/end markers still sit on the real endpoints.
///
/// Pure, so it can be tested without a database.
List<LatLng> downsamplePolyline(List<LatLng> points, int budget) {
  if (budget < 2 || points.length <= budget) return points;

  final step = (points.length - 1) / (budget - 1);
  final out = <LatLng>[
    for (var i = 0; i < budget - 1; i++) points[(i * step).floor()],
    points.last,
  ];
  return out;
}
