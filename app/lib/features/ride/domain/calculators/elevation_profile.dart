/// Elevation gain/loss estimated from a ride's raw barometric/GPS altitude
/// samples (`ride_points.altitude_m`).
///
/// Raw altitude is noisy — summing every raw sample-to-sample delta would
/// count sensor jitter as climbing and descending, wildly overstating both.
/// A short moving average smooths that jitter out before deltas are summed,
/// the same "don't trust raw deltas" principle `speed_baseline.dart` and
/// `jam_time.dart` already apply to their own noisy inputs.
///
/// Returns null when there isn't enough honest signal to report: too few
/// samples, mostly-missing altitude (no barometer/GPS altitude fix on this
/// device or ride), or variation so small it's plausibly all noise floor —
/// an unreliable number is worse than no number, matching this app's
/// established policy for anything insight-like (see `RideEntity.jamSeconds`,
/// the speed-outlier card).
({double gainM, double lossM})? elevationGainLoss(
  List<double?> altitudesM, {
  int smoothingWindow = 5,
  double minVariationM = 3.0,
  double minPresentFraction = 0.5,
}) {
  if (altitudesM.isEmpty) return null;

  final present = altitudesM.whereType<double>().toList();
  if (present.length / altitudesM.length < minPresentFraction) return null;
  if (present.length < smoothingWindow * 2) return null;

  final half = smoothingWindow ~/ 2;
  final smoothed = <double>[
    for (var i = 0; i < present.length; i++)
      () {
        final start = (i - half).clamp(0, present.length - 1);
        final end = (i + half).clamp(0, present.length - 1);
        final window = present.sublist(start, end + 1);
        return window.reduce((a, b) => a + b) / window.length;
      }(),
  ];

  final minAlt = smoothed.reduce((a, b) => a < b ? a : b);
  final maxAlt = smoothed.reduce((a, b) => a > b ? a : b);
  if (maxAlt - minAlt < minVariationM) return null;

  double gain = 0;
  double loss = 0;
  for (var i = 1; i < smoothed.length; i++) {
    final delta = smoothed[i] - smoothed[i - 1];
    if (delta > 0) {
      gain += delta;
    } else {
      loss += -delta;
    }
  }
  return (gainM: gain, lossM: loss);
}

/// The elevation figure stored on a ride row (schema v26), or null when the
/// altitude data can't support one.
///
/// Same estimate as [elevationGainLoss], with one difference: a ride with
/// plenty of altitude samples whose total variation is inside the noise
/// floor is stored as a measured `0 m / 0 m` (it was flat), not as unknown.
/// [elevationGainLoss] returns null for both cases because its caller (the
/// ride summary) hides the section either way; a stored column has to tell
/// them apart, or the backfill would rescan every flat ride on every start.
({double gainM, double lossM})? rideElevationGainLoss(
  List<double?> altitudesM, {
  int smoothingWindow = 5,
  double minVariationM = 3.0,
  double minPresentFraction = 0.5,
}) {
  final result = elevationGainLoss(
    altitudesM,
    smoothingWindow: smoothingWindow,
    minVariationM: minVariationM,
    minPresentFraction: minPresentFraction,
  );
  if (result != null) return result;
  if (altitudesM.isEmpty) return null;
  final present = altitudesM.whereType<double>().length;
  if (present / altitudesM.length < minPresentFraction) return null;
  if (present < smoothingWindow * 2) return null;
  // Enough honest samples, just no climb worth reporting.
  return (gainM: 0.0, lossM: 0.0);
}
