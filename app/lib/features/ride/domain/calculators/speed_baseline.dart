import 'dart:math';

/// Historical speed baseline for one road-segment (see
/// `segment_speed_aggregator.dart`), computed from anonymous pooled samples.
typedef SegmentBaseline = ({int sampleCount, double meanKmh, double stddevKmh});

/// Reduces a segment's historical sample speeds to a baseline. Returns null
/// for an empty pool rather than a fabricated zero baseline.
SegmentBaseline? computeBaseline(List<double> historicalSpeedsKmh) {
  if (historicalSpeedsKmh.isEmpty) return null;

  final mean =
      historicalSpeedsKmh.reduce((a, b) => a + b) / historicalSpeedsKmh.length;
  final variance = historicalSpeedsKmh
          .map((s) => (s - mean) * (s - mean))
          .reduce((a, b) => a + b) /
      historicalSpeedsKmh.length;

  return (
    sampleCount: historicalSpeedsKmh.length,
    meanKmh: mean,
    stddevKmh: variance <= 0 ? 0 : sqrt(variance),
  );
}

/// Whether [speedKmh] on a segment is a meaningful outlier against
/// [baseline].
///
/// Requires BOTH a statistical jump (z-score past [zThreshold]) AND an
/// absolute [minDeltaKmh] gap above the mean — a segment that's always
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
  if (speedKmh - baseline.meanKmh < minDeltaKmh) return false;
  if (baseline.stddevKmh <= 0) return true; // any excess over a flat baseline
  final z = (speedKmh - baseline.meanKmh) / baseline.stddevKmh;
  return z >= zThreshold;
}
