/// Where the rider is along a saved route, and what that means for the
/// guidance banner.
///
/// This used to live inside `RouteNavigationScreen` as a mix of `setState`
/// bookkeeping and expressions in `build()`, which meant none of it could be
/// tested and it could only ever run against that screen's own GPS stream.
/// Pulling it out is what lets the *recorder's* fixes drive navigation
/// (see `navigation_session_provider.dart`) — one GPS stream, not two.
///
/// Everything here is pure (no Flutter, no I/O, no singletons) — see
/// `test/features/routes/navigation_progress_test.dart`.
library;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/geo_math.dart';
import 'turn_instruction.dart';

/// How close the rider must get to a manoeuvre's point before it counts as
/// done and the banner advances to the next one.
const double kTurnReachedM = 30;

/// Distance from the nearest point on the route past which the rider is told
/// they're off route.
///
/// Generous on purpose: this follows a breadcrumb trail recorded by a phone in
/// a pocket, so the line itself carries GPS error, and a rider in the correct
/// lane can sit tens of metres off it through no fault of their own. Crying
/// "off route" at every underpass trains riders to ignore the banner.
const double kOffRouteM = 100;

/// How close to the route's final point counts as having arrived.
const double kArrivedM = 40;

/// Speed below which no ETA is shown. Extrapolating an arrival time from
/// 0 m/s divides by zero, and from a crawl produces an absurd number — a rider
/// stopped at a Dhaka intersection would be told they arrive next Tuesday.
const double kMinEtaSpeedMs = 1.0;

/// A snapshot of "how am I doing against this route", derived entirely from
/// the route's polyline and the latest fix.
class NavigationProgress extends Equatable {
  /// Index into the instruction list of the manoeuvre being ridden toward, or
  /// -1 when the route has no instructions at all.
  final int turnIndex;

  /// Distance to [turnIndex]'s point. Null before the first fix, or when
  /// there is no instruction to head for.
  final double? metresToTurn;

  /// Distance still to ride, measured along the line. Before the first fix
  /// this is the whole route.
  final double metresRemaining;

  /// How far the rider is from the nearest point on the route. Null before the
  /// first fix — which is why [isOffRoute] is false then rather than true.
  final double? offRouteM;

  /// Seconds to the end at the current speed, or null while stopped, before
  /// the first fix, or once arrived.
  final int? etaSeconds;

  /// True once the rider is within [kArrivedM] of the route's last point.
  final bool arrived;

  /// Polyline index the rider was last matched to. Carried into the next fix
  /// so matching only searches forward from here (issues §101.R6): on a loop
  /// the start and end are the same place, and a global nearest search at the
  /// start used to snap to the end.
  final int nearestIndex;

  const NavigationProgress({
    required this.turnIndex,
    required this.metresToTurn,
    required this.metresRemaining,
    required this.offRouteM,
    required this.etaSeconds,
    required this.arrived,
    this.nearestIndex = 0,
  });

  /// The state before any fix has arrived: everything unknown, the whole route
  /// still ahead.
  factory NavigationProgress.initial(List<LatLng> polyline) =>
      NavigationProgress(
        turnIndex: 0,
        metresToTurn: null,
        metresRemaining: remainingDistanceM(polyline, 0),
        offRouteM: null,
        etaSeconds: null,
        arrived: false,
      );

  bool get isOffRoute => offRouteM != null && offRouteM! > kOffRouteM;

  @override
  List<Object?> get props => [
        turnIndex,
        metresToTurn,
        metresRemaining,
        offRouteM,
        etaSeconds,
        arrived,
        nearestIndex,
      ];

  @override
  String toString() => 'NavigationProgress(turn $turnIndex, '
      '${metresRemaining.toStringAsFixed(0)}m left, offRoute=$offRouteM, '
      'eta=$etaSeconds, arrived=$arrived)';
}

/// Advances [from] past every manoeuvre the rider has either reached or
/// already ridden past.
///
/// Two conditions, and the second is the one that matters. Proximity alone —
/// "am I within [reachedM] of this turn's point?" — is how the old navigation
/// screen did it, and it sticks: a rider who takes a corner in the far lane,
/// or whose fix lands 40 m wide of a recorded trail, never enters the ball and
/// the banner points at that turn for the rest of the ride. So a manoeuvre
/// whose point lies *behind* the rider's position along the line is treated as
/// done regardless of how widely it was passed.
///
/// A loop, not a single step, so a gap in fixes — a tunnel, a phone asleep in
/// a pocket — can't leave guidance several turns in arrears. Never advances
/// onto the last instruction's successor: `arrive` is the terminus.
///
/// Only ever moves forward, because [from] is carried in rather than derived:
/// a rider who doubles back doesn't get earlier turns re-announced.
int advanceTurnIndex({
  required List<LatLng> polyline,
  required List<TurnInstruction> turns,
  required LatLng position,
  required int from,
  double reachedM = kTurnReachedM,

  /// The rider's matched polyline index, when the caller already has a
  /// forward-only one. Defaults to a global nearest search.
  int? nearestIndex,
}) {
  if (turns.isEmpty) return -1;
  var next = from.clamp(0, turns.length - 1);
  if (polyline.isEmpty) return next;

  final matchedIndex =
      nearestIndex ?? nearestPointOnPolyline(polyline, position)?.index;
  while (next < turns.length - 1) {
    final pointIndex = turns[next].pointIndex;
    if (pointIndex < 0 || pointIndex >= polyline.length) break;
    final reached =
        haversineMetersLatLng(position, polyline[pointIndex]) <= reachedM;
    final passed = matchedIndex != null && pointIndex < matchedIndex;
    if (!reached && !passed) break;
    next++;
  }
  return next;
}

/// How far ahead (along the line) of the previous match to look for the
/// rider's new position.
const double kForwardWindowM = 500;

/// Nearest polyline point searching only forward from [fromIndex], within
/// [windowM] of line length. Falls back to a global search when the best
/// match is beyond [kOffRouteM] (off route, or a gap longer than the window),
/// which is the only time a match may jump.
({int index, double distanceM})? forwardNearestPoint(
  List<LatLng> polyline,
  LatLng position, {
  int fromIndex = 0,
  double windowM = kForwardWindowM,
}) {
  if (polyline.isEmpty) return null;
  final start = fromIndex.clamp(0, polyline.length - 1);
  var bestIndex = start;
  var bestDistance = haversineMetersLatLng(polyline[start], position);
  var walked = 0.0;
  for (var i = start + 1; i < polyline.length && walked <= windowM; i++) {
    walked += haversineMetersLatLng(polyline[i - 1], polyline[i]);
    final d = haversineMetersLatLng(polyline[i], position);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
    }
  }
  if (bestDistance > kOffRouteM) return nearestPointOnPolyline(polyline, position);
  return (index: bestIndex, distanceM: bestDistance);
}

/// Seconds to cover [metres] at [speedMs], or null when that number would be
/// meaningless — see [kMinEtaSpeedMs].
int? etaSeconds(double metres, double? speedMs) {
  if (speedMs == null || speedMs < kMinEtaSpeedMs) return null;
  if (metres <= 0) return 0;
  return (metres / speedMs).round();
}

/// The full picture for one fix.
///
/// [previousTurnIndex] is the last value this function returned, so the
/// manoeuvre pointer only ever moves forward; passing 0 restarts it.
/// [previousNearestIndex] likewise is the last matched polyline index, and
/// [previouslyArrived] latches arrival (issues §101.R6): without them a loop
/// route read "arrived" at its own start, and leaving the end zone un-arrived.
/// A null [position] (no fix yet) yields [NavigationProgress.initial].
NavigationProgress computeNavigationProgress({
  required List<LatLng> polyline,
  required List<TurnInstruction> turns,
  required int previousTurnIndex,
  int previousNearestIndex = 0,
  bool previouslyArrived = false,
  LatLng? position,
  double? speedMs,
}) {
  if (position == null || polyline.isEmpty) {
    final initial = NavigationProgress.initial(polyline);
    return turns.isEmpty
        ? NavigationProgress(
            turnIndex: -1,
            metresToTurn: null,
            metresRemaining: initial.metresRemaining,
            offRouteM: null,
            etaSeconds: null,
            arrived: false,
          )
        : initial;
  }

  final nearest = forwardNearestPoint(polyline, position,
      fromIndex: previousNearestIndex);
  final turnIndex = advanceTurnIndex(
    polyline: polyline,
    turns: turns,
    position: position,
    from: previousTurnIndex,
    nearestIndex: nearest?.index,
  );

  final metresToTurn = (turnIndex >= 0 &&
          turns[turnIndex].pointIndex >= 0 &&
          turns[turnIndex].pointIndex < polyline.length)
      ? haversineMetersLatLng(position, polyline[turns[turnIndex].pointIndex])
      : null;

  final metresRemaining =
      nearest == null ? 0.0 : remainingDistanceM(polyline, nearest.index);

  // Near the end is not enough: on a loop the start is near the end too.
  // The rider must also be on the last manoeuvre and on the last stretch of
  // the line. Once true it stays true.
  final onLastTurn = turns.isEmpty || turnIndex >= turns.length - 1;
  final arrived = previouslyArrived ||
      (onLastTurn &&
          metresRemaining <= 2 * kArrivedM &&
          haversineMetersLatLng(position, polyline.last) <= kArrivedM);

  return NavigationProgress(
    turnIndex: turnIndex,
    metresToTurn: metresToTurn,
    metresRemaining: metresRemaining,
    offRouteM: nearest?.distanceM,
    etaSeconds: arrived ? null : etaSeconds(metresRemaining, speedMs),
    arrived: arrived,
    nearestIndex: nearest?.index ?? previousNearestIndex,
  );
}
