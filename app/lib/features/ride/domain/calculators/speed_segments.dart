/// Speed bucket for route-map coloring, so a rider can see at a glance which
/// road (or which part of one) they took at what pace.
///
/// Fixed km/h thresholds rather than per-ride relative scaling — "I hit 90"
/// should read as fast on every ride, not only relative to today's other
/// samples. Motorcycle-tuned; revisit the cutoffs if this misreads for rides
/// that are mostly highway.
enum SpeedBand { idle, normal, brisk, hard }

SpeedBand speedBandForKmh(double kmh) {
  if (kmh < 5) return SpeedBand.idle;
  if (kmh < 50) return SpeedBand.normal;
  if (kmh < 90) return SpeedBand.brisk;
  return SpeedBand.hard;
}

/// A run of consecutive points that all fall in the same [SpeedBand],
/// suitable for rendering as one colored polyline segment. Generic over the
/// point type so this stays Flutter-free and testable with plain records —
/// the caller supplies whatever point type it already has (e.g. `LatLng`).
typedef SpeedSegment<P> = ({List<P> points, SpeedBand band});

/// Groups [points] (in ride order) into same-band runs.
///
/// [speedsMs] must be the same length as [points] — index-paired, not a
/// separate lookup, since both lists are always built from the same ordered
/// query. Each run repeats the point where the band changed as the first
/// point of the following run, so adjacent segments still share an endpoint
/// and the drawn line has no visual gap at the color boundary.
List<SpeedSegment<P>> buildSpeedSegments<P>(
  List<P> points,
  List<double> speedsMs,
) {
  if (points.length < 2 || points.length != speedsMs.length) return [];

  final segments = <SpeedSegment<P>>[];
  var band = speedBandForKmh(speedsMs[0] * 3.6);
  var current = <P>[points[0]];

  for (var i = 1; i < points.length; i++) {
    final nextBand = speedBandForKmh(speedsMs[i] * 3.6);
    current.add(points[i]);
    if (nextBand != band) {
      segments.add((points: List<P>.of(current), band: band));
      current = <P>[points[i]];
      band = nextBand;
    }
  }
  if (current.length > 1) {
    segments.add((points: List<P>.of(current), band: band));
  }
  return segments;
}
