import '../../ride/domain/entities/ride_entity.dart';
import '../../../core/utils/riding_score.dart';

/// How the rides list is ordered.
///
/// Pure and Flutter-free so the ordering can be tested directly — see
/// `test/features/stats/ride_sort_test.dart`.
enum RideSort {
  recent,
  topSpeed,
  longestDistance,
  longestDuration,
  bestScore,
}

extension RideSortLabel on RideSort {
  /// Short label for the sort chips.
  String get label {
    switch (this) {
      case RideSort.recent:
        return 'Recent';
      case RideSort.topSpeed:
        return 'Top speed';
      case RideSort.longestDistance:
        return 'Distance';
      case RideSort.longestDuration:
        return 'Duration';
      case RideSort.bestScore:
        return 'Best score';
    }
  }

  /// The value this ordering ranks by, rendered for the row's trailing text so
  /// the list visibly explains its own order. Null for [RideSort.recent],
  /// where the date already shown is the sort key.
  String? Function(RideEntity) get trailingValue {
    switch (this) {
      case RideSort.recent:
        return (_) => null;
      case RideSort.topSpeed:
        return (r) => '${r.maxSpeedKmh.toStringAsFixed(0)} km/h';
      case RideSort.longestDistance:
        return (r) => '${r.distanceKm.toStringAsFixed(1)} km';
      case RideSort.longestDuration:
        return (r) => _durationLabel(r.durationSeconds);
      case RideSort.bestScore:
        return (r) => '${rideScoreOf(r)}';
    }
  }
}

String _durationLabel(int? seconds) {
  final s = seconds ?? 0;
  if (s < 60) return '${s}s';
  final minutes = s ~/ 60;
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// The smoothness score for one ride, using the same maths the summary screen
/// shows so the "Best score" ordering can't disagree with what a rider sees on
/// the ride itself.
int rideScoreOf(RideEntity ride) => computeRidingScore(
      hardBrakes: ride.hardBrakeCount,
      rapidAccel: ride.rapidAccelCount,
      highJerk: ride.highJerkCount,
    );

/// Orders [rides] by [sort], newest/highest first.
///
/// Returns a NEW list — the input is never mutated, because callers pass
/// provider-owned lists that must not be reordered underneath other widgets.
///
/// Every non-recency ordering falls back to recency for ties. Without that,
/// two rides with identical distance (very common — a repeated commute, or
/// several 0.0 km test rides) would land in whatever order the database
/// happened to return, and the list would reshuffle between rebuilds for no
/// visible reason.
///
/// Missing values sort last rather than first: a ride with no recorded
/// duration or top speed is a data gap, and surfacing it at the top of
/// "Longest ride" would be actively wrong.
List<RideEntity> sortRides(List<RideEntity> rides, RideSort sort) {
  final out = [...rides];

  int byRecency(RideEntity a, RideEntity b) => b.startTime.compareTo(a.startTime);

  switch (sort) {
    case RideSort.recent:
      out.sort(byRecency);
    case RideSort.topSpeed:
      out.sort((a, b) {
        final c = (b.maxSpeedMs ?? 0).compareTo(a.maxSpeedMs ?? 0);
        return c != 0 ? c : byRecency(a, b);
      });
    case RideSort.longestDistance:
      out.sort((a, b) {
        final c = b.distanceM.compareTo(a.distanceM);
        return c != 0 ? c : byRecency(a, b);
      });
    case RideSort.longestDuration:
      out.sort((a, b) {
        final c = (b.durationSeconds ?? 0).compareTo(a.durationSeconds ?? 0);
        return c != 0 ? c : byRecency(a, b);
      });
    case RideSort.bestScore:
      out.sort((a, b) {
        final c = rideScoreOf(b).compareTo(rideScoreOf(a));
        return c != 0 ? c : byRecency(a, b);
      });
  }
  return out;
}
