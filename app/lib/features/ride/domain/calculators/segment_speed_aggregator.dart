import '../../../../core/utils/geohash_util.dart';

/// One geohash-cell "segment" this ride passed through, and the average
/// speed it was ridden at while inside that cell.
typedef SegmentSpeedSample = ({String segmentId, double avgSpeedKmh, int pointCount});

/// Precision 7 geohash cells are roughly 150m × 150m at the latitudes this
/// app's riders are ever at — small enough to separate distinct stretches of
/// road, large enough that a beta-scale rider base can actually accumulate
/// more than one sample per cell. Not true map-matching: a straight road and
/// the curved one crossing it at the same spot fall into the same cell. See
/// `Features.md` for why that tradeoff was made — it ships without a paid
/// roads-API vendor decision.
const int defaultSegmentPrecision = 7;

/// Buckets [points] (in ride order, m/s speeds) into geohash-cell segments
/// and averages the speed within each cell. Pure — no Firestore/network
/// dependency — so the per-ride contribution this feeds can be tested
/// without a live backend.
List<SegmentSpeedSample> averageSpeedPerSegment(
  List<({double lat, double lng, double speedMs})> points, {
  int precision = defaultSegmentPrecision,
}) {
  final sums = <String, double>{};
  final counts = <String, int>{};

  for (final p in points) {
    final id = GeohashUtil.encode(p.lat, p.lng, precision: precision);
    sums[id] = (sums[id] ?? 0) + p.speedMs * 3.6;
    counts[id] = (counts[id] ?? 0) + 1;
  }

  return [
    for (final id in sums.keys)
      (segmentId: id, avgSpeedKmh: sums[id]! / counts[id]!, pointCount: counts[id]!),
  ];
}
