/// Historical speed baseline for one road-segment (see
/// `segment_speed_aggregator.dart`), computed from anonymous pooled samples.
/// [stddevKmh] is a robust estimate (1.4826 × the median absolute deviation),
/// which equals the standard deviation for normally spread speeds.
typedef SegmentBaseline = ({
  int sampleCount,
  double medianKmh,
  double stddevKmh
});

/// Reduces a segment's historical sample speeds to a baseline. Returns null
/// for an empty pool rather than a fabricated zero baseline.
///
/// Median and MAD, not mean and stddev: any signed-in rider can write to the
/// pool, and while honest samples are the majority, forged ones can't move
/// either figure out of the honest range however extreme they are.
SegmentBaseline? computeBaseline(List<double> historicalSpeedsKmh) {
  if (historicalSpeedsKmh.isEmpty) return null;

  final median = _median(historicalSpeedsKmh);
  final mad =
      _median([for (final s in historicalSpeedsKmh) (s - median).abs()]);

  return (
    sampleCount: historicalSpeedsKmh.length,
    medianKmh: median,
    stddevKmh: 1.4826 * mad,
  );
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Whether [speedKmh] on a segment is a meaningful outlier against
/// [baseline].
///
/// Requires BOTH a statistical jump (z-score past [zThreshold]) AND an
/// absolute [minDeltaKmh] gap above the median — a segment that's always
/// exactly 0 km/h (a stop sign) has ~zero stddev, and z-score alone would
/// flag a single moving fix there as "infinitely" outlying. [minSamples]
/// guards the case that matters most at beta scale: with only 1-2 historical
/// samples, "the baseline" is one other rider's ride, not a real norm, so
/// nothing is flagged until there's enough pool to mean something.
bool isSpeedOutlier(
  double speedKmh,
  SegmentBaseline baseline, {
  double zThreshold = 2.5,
  double minDeltaKmh = 20,
  int minSamples = 5,
}) {
  if (baseline.sampleCount < minSamples) return false;
  if (speedKmh - baseline.medianKmh < minDeltaKmh) return false;
  if (baseline.stddevKmh <= 0) return true; // any excess over a flat baseline
  final z = (speedKmh - baseline.medianKmh) / baseline.stddevKmh;
  return z >= zThreshold;
}
