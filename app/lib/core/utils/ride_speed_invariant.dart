import '../constants/sensor_constants.dart';

/// Single source of truth for the "max speed can never be below average speed,
/// and never above a physically-plausible ceiling" invariant that a ride's
/// stats must satisfy wherever they're displayed or shared.
///
/// docs/Issues.md §62.8: this floor was independently reimplemented in three
/// places (RideEntity.maxSpeedKmh, RideShareModel's constructor and
/// fromFirestore, SharedRideEntity.maxSpeedKmh) and only one of them also
/// applied the upper-bound clamp — so a shared ride's maxSpeedKmh could be
/// left unbounded above. All four now call through here instead.
class RideSpeedInvariant {
  const RideSpeedInvariant._();

  /// The ceiling in km/h, derived from the single m/s constant so there's
  /// never a second magic number to drift out of sync with it.
  static double get ceilingKmh => SensorConstants.maxPlausibleSpeedMs * 3.6;

  /// Reconciles an already-computed [avgSpeedKmh] against a raw/reported
  /// [rawMaxSpeedKmh]: floors the max up to the average when it's missing or
  /// implausibly low, then clamps the result to [ceilingKmh].
  static double reconcile({
    required double avgSpeedKmh,
    required double rawMaxSpeedKmh,
  }) {
    final effective = (rawMaxSpeedKmh <= 0 && avgSpeedKmh > 0)
        ? avgSpeedKmh
        : (rawMaxSpeedKmh < avgSpeedKmh ? avgSpeedKmh : rawMaxSpeedKmh);
    return effective > ceilingKmh ? ceilingKmh : effective;
  }

  /// Convenience wrapper for callers that only have distance/duration rather
  /// than a precomputed average speed (RideShareModel, SharedRideEntity).
  static double reconcileFromDistance({
    required double distanceKm,
    required num durationSeconds,
    required double rawMaxSpeedKmh,
  }) {
    final avgSpeedKmh = (distanceKm > 0 && durationSeconds > 0)
        ? (distanceKm / durationSeconds) * 3600
        : 0.0;
    return reconcile(avgSpeedKmh: avgSpeedKmh, rawMaxSpeedKmh: rawMaxSpeedKmh);
  }
}
