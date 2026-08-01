/// Turn-by-turn guidance derived *geometrically* from a saved route's own
/// polyline.
///
/// There is deliberately no routing engine and no map-provider API key behind
/// this: a saved route is a trail the rider has already physically ridden, so
/// its recorded GPS points already describe the road. Reading the turns back
/// out of that shape is fully offline, costs nothing, and can never disagree
/// with the line drawn on the map — which a third-party route-matching service
/// absolutely can. The trade-off is that we get geometry, not road data: no
/// street names, no lane guidance, no "at the roundabout take the 2nd exit".
///
/// Everything in this file is pure (no Flutter, no I/O, no singletons) so the
/// classification can be unit-tested directly — see
/// `test/features/routes/turn_instruction_test.dart`.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// The shape of a manoeuvre at one point along a route.
enum TurnKind {
  start,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,

  /// Emitted by [classifyBearingDelta] for a heading change too small to be a
  /// manoeuvre. [buildTurnInstructions] never emits an *instruction* with this
  /// kind — a straight stretch is simply the absence of a turn — but the value
  /// exists so the classifier is total and directly testable.
  straight,

  arrive,
}

/// One manoeuvre along a route.
class TurnInstruction extends Equatable {
  /// Index into the ORIGINAL polyline passed to [buildTurnInstructions] (not
  /// into the simplified working copy) — so a navigation screen can look the
  /// turn's coordinate straight back up in the polyline it is drawing.
  final int pointIndex;

  final TurnKind kind;

  /// Forward azimuth (0-360, 0 = north) the rider should be travelling on
  /// *after* completing this manoeuvre. For [TurnKind.arrive] this is the
  /// bearing of the final segment.
  final double bearingDeg;

  /// Distance from the start of the route to [pointIndex], measured along the
  /// full polyline.
  final double distanceFromStartM;

  /// Human-readable banner text, e.g. `'Turn right'`, `'Slight left'`.
  final String text;

  const TurnInstruction({
    required this.pointIndex,
    required this.kind,
    required this.bearingDeg,
    required this.distanceFromStartM,
    required this.text,
  });

  @override
  List<Object?> get props => [pointIndex, kind, bearingDeg, distanceFromStartM, text];

  @override
  String toString() =>
      'TurnInstruction($kind @ $pointIndex, ${distanceFromStartM.toStringAsFixed(0)}m, "$text")';
}

const double _earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;
double _deg(double rad) => rad * 180.0 / math.pi;

/// Great-circle distance between two points, in metres.
///
/// The app already has three private copies of this formula
/// (`GeohashUtils.calculateDistance` returns km and lives in the POI feature,
/// `RideRecordingNotifier._haversineMeters` is private, `MotionCalculator`
/// keeps its own) — none of them is both public and metre-denominated, so
/// rather than reach across features for a km value and multiply it back up,
/// this module exposes its own metre version as a first-class testable helper.
double haversineMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return _earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Standard forward azimuth from [from] to [to], normalized to [0, 360).
/// 0 = due north, 90 = due east.
double bearingDegrees(LatLng from, LatLng to) {
  final lat1 = _rad(from.latitude);
  final lat2 = _rad(to.latitude);
  final dLng = _rad(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360.0) % 360.0;
}

/// Signed change in heading, normalized to (-180, 180].
///
/// Positive = turning right (clockwise), negative = turning left. Doing this
/// with a plain subtraction is the classic wraparound bug: 350° → 10° is a 20°
/// right turn, not a 340° left one.
double normalizeBearingDelta(double deltaDeg) {
  var d = deltaDeg % 360.0;
  if (d <= -180.0) d += 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

/// Buckets a signed heading change (as produced by [normalizeBearingDelta])
/// into a manoeuvre. Magnitude picks the severity, sign picks the side.
/// Per-segment heading change below which a segment counts as "still going
/// straight" for the purpose of grouping a bend.
///
/// Deliberately well under [classifyBearingDelta]'s own 20-degree floor: a
/// long sweeping corner arrives as many small deltas that individually look
/// straight but together add up to a real turn, and those should group into
/// one manoeuvre. Set this too low and GPS jitter on a dead-straight road
/// starts accumulating — though jitter alternates direction, and a direction
/// reversal ends the run, so the failure mode is bounded.
const double _straightToleranceDeg = 8.0;

TurnKind classifyBearingDelta(double delta) {
  final magnitude = delta.abs();
  if (magnitude < 20.0) return TurnKind.straight;
  if (magnitude > 160.0) return TurnKind.uTurn;

  final right = delta > 0;
  if (magnitude < 45.0) return right ? TurnKind.slightRight : TurnKind.slightLeft;
  if (magnitude < 120.0) return right ? TurnKind.right : TurnKind.left;
  return right ? TurnKind.sharpRight : TurnKind.sharpLeft;
}

/// Banner text for a manoeuvre. [TurnKind.start] is handled separately by
/// [buildTurnInstructions] because its wording carries a compass direction.
String turnText(TurnKind kind) {
  switch (kind) {
    case TurnKind.start:
      return 'Start';
    case TurnKind.slightLeft:
      return 'Slight left';
    case TurnKind.left:
      return 'Turn left';
    case TurnKind.sharpLeft:
      return 'Sharp left';
    case TurnKind.slightRight:
      return 'Slight right';
    case TurnKind.right:
      return 'Turn right';
    case TurnKind.sharpRight:
      return 'Sharp right';
    case TurnKind.uTurn:
      return 'Make a U-turn';
    case TurnKind.straight:
      return 'Continue straight';
    case TurnKind.arrive:
      return 'You have arrived';
  }
}

const List<String> _compassPoints = [
  'north',
  'north-east',
  'east',
  'south-east',
  'south',
  'south-west',
  'west',
  'north-west',
];

/// Nearest 8-point compass name for a bearing, e.g. 47° → `'north-east'`.
String compassDirection(double bearingDeg) {
  final normalized = (bearingDeg % 360.0 + 360.0) % 360.0;
  final index = ((normalized + 22.5) ~/ 45) % 8;
  return _compassPoints[index];
}

/// Derives the manoeuvre list for [polyline].
///
/// Recorded GPS trails are noisy at metre scale — standing at a light produces
/// a cluster of jittering fixes whose consecutive bearings swing wildly and
/// would otherwise read as a flurry of turns. So the line is first simplified
/// by dropping every point within [minSegmentM] of the last point kept; the
/// remaining segments are long enough that their bearings mean something.
///
/// Returns an empty list for a polyline too short to have any shape (fewer
/// than two points). Otherwise the result always begins with a
/// [TurnKind.start] and ends with a [TurnKind.arrive], with zero or more turns
/// between them; straight stretches emit nothing.
List<TurnInstruction> buildTurnInstructions(
  List<LatLng> polyline, {
  double minSegmentM = 25,
}) {
  if (polyline.length < 2) return const [];

  // Cumulative distance along the FULL polyline, so every instruction's
  // distanceFromStartM is measured against the line actually drawn on screen
  // rather than against the simplified working copy.
  final cumulative = List<double>.filled(polyline.length, 0);
  for (var i = 1; i < polyline.length; i++) {
    cumulative[i] = cumulative[i - 1] + haversineMeters(polyline[i - 1], polyline[i]);
  }

  // Simplify: indices into the original polyline.
  final kept = <int>[0];
  for (var i = 1; i < polyline.length; i++) {
    if (haversineMeters(polyline[kept.last], polyline[i]) >= minSegmentM) {
      kept.add(i);
    }
  }

  final lastIndex = polyline.length - 1;

  // Every simplified segment's forward azimuth. Degenerate (zero-length)
  // segments can't have one and are skipped — atan2(0, 0) is 0, which would
  // read as a bogus due-north heading.
  final segmentStart = <int>[];
  final bearings = <double>[];
  for (var j = 0; j + 1 < kept.length; j++) {
    final a = polyline[kept[j]];
    final b = polyline[kept[j + 1]];
    if (haversineMeters(a, b) < 1e-6) continue;
    segmentStart.add(kept[j]);
    bearings.add(bearingDegrees(a, b));
  }

  // The whole polyline sat inside one minSegmentM ball (or is a repeated
  // point): no usable heading anywhere. Fall back to the straight line from
  // first to last so the rider still gets a start + arrive pair.
  if (bearings.isEmpty) {
    final fallbackBearing = haversineMeters(polyline.first, polyline[lastIndex]) < 1e-6
        ? 0.0
        : bearingDegrees(polyline.first, polyline[lastIndex]);
    return [
      TurnInstruction(
        pointIndex: 0,
        kind: TurnKind.start,
        bearingDeg: fallbackBearing,
        distanceFromStartM: 0,
        text: 'Head ${compassDirection(fallbackBearing)}',
      ),
      TurnInstruction(
        pointIndex: lastIndex,
        kind: TurnKind.arrive,
        bearingDeg: fallbackBearing,
        distanceFromStartM: cumulative[lastIndex],
        text: turnText(TurnKind.arrive),
      ),
    ];
  }

  final instructions = <TurnInstruction>[
    TurnInstruction(
      pointIndex: 0,
      kind: TurnKind.start,
      bearingDeg: bearings.first,
      distanceFromStartM: 0,
      text: 'Head ${compassDirection(bearings.first)}',
    ),
  ];

  // Accumulate consecutive same-direction heading changes into ONE manoeuvre.
  //
  // A real corner is rarely a single clean vertex: GPS samples it across
  // several points, so a 90-degree right arrives as e.g. 72 then 18 degrees
  // over two segments. Emitted naively that becomes "Turn right" followed
  // 50 m later by "Slight right" for the same physical corner — noisy to
  // ride to, and it under-states the first turn. So a run of deltas that
  // keep bending the same way, with no meaningful straight stretch between
  // them, is summed and classified once, anchored at where the bend began.
  var runDelta = 0.0;
  var runStartSegment = -1;
  var runEndSegment = -1;

  void flushRun() {
    if (runStartSegment < 0) return;
    final kind = classifyBearingDelta(runDelta);
    if (kind != TurnKind.straight) {
      final index = segmentStart[runStartSegment];
      instructions.add(TurnInstruction(
        pointIndex: index,
        kind: kind,
        // The heading the rider ends up on once the whole bend is done.
        bearingDeg: bearings[runEndSegment],
        distanceFromStartM: cumulative[index],
        text: turnText(kind),
      ));
    }
    runDelta = 0;
    runStartSegment = -1;
    runEndSegment = -1;
  }

  for (var j = 1; j < bearings.length; j++) {
    final delta = normalizeBearingDelta(bearings[j] - bearings[j - 1]);

    // A genuinely straight segment ends whatever bend was in progress.
    if (delta.abs() < _straightToleranceDeg) {
      flushRun();
      continue;
    }

    // Direction reversal (right after left) is a new manoeuvre, not a
    // continuation — an S-bend must stay two instructions.
    if (runStartSegment >= 0 && (delta < 0) != (runDelta < 0)) {
      flushRun();
    }

    if (runStartSegment < 0) runStartSegment = j;
    runEndSegment = j;
    runDelta += delta;
  }
  flushRun();

  instructions.add(TurnInstruction(
    pointIndex: lastIndex,
    kind: TurnKind.arrive,
    bearingDeg: bearings.last,
    distanceFromStartM: cumulative[lastIndex],
    text: turnText(TurnKind.arrive),
  ));

  return instructions;
}

/// Index of the polyline point nearest to [position], paired with its distance
/// in metres. Used by the navigation screen for both "how far off route am I"
/// and "how much of the route is left". Returns `null` for an empty polyline.
({int index, double distanceM})? nearestPointOnPolyline(
  List<LatLng> polyline,
  LatLng position,
) {
  if (polyline.isEmpty) return null;
  var bestIndex = 0;
  var bestDistance = haversineMeters(polyline[0], position);
  for (var i = 1; i < polyline.length; i++) {
    final d = haversineMeters(polyline[i], position);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
    }
  }
  return (index: bestIndex, distanceM: bestDistance);
}

/// Distance in metres from [fromIndex] to the end of [polyline], measured
/// along the line.
double remainingDistanceM(List<LatLng> polyline, int fromIndex) {
  if (polyline.length < 2 || fromIndex >= polyline.length - 1) return 0;
  var total = 0.0;
  for (var i = math.max(fromIndex, 0); i + 1 < polyline.length; i++) {
    total += haversineMeters(polyline[i], polyline[i + 1]);
  }
  return total;
}
