/// The auto-tracking end-of-day summary: one honest count of the day's rides,
/// manual and forgotten alike, instead of a list of background fragments.
///
/// ## Why this exists
///
/// The background detector closes a detection after
/// `AutoTrackingService.stillnessTimeout` (5 min) of non-vehicle activity. A
/// Dhaka jam regularly sits still for longer than that, so one commute came
/// out as 2, 3, 5 separate "rides". Rather than surfacing each fragment, the
/// day is summarised: fragments separated by at most [SensorConstants.
/// autoRideMergeGap] are merged into one ride, and the gap is counted as
/// ride time spent in traffic.
///
/// Pure (no SQLite, no platform) so it can be tested directly; see
/// `daily_ride_summary_test.dart`. Raw detection data is untouched by any of
/// this — it only decides what is counted.
library;

import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/utils/geo_math.dart';
import 'auto_ride_reconciler.dart';
import 'jam_time.dart' as jam;

/// Where a segment of riding came from.
enum DaySegmentSource {
  /// A ride row: recorded by hand (or promoted by the pre-summary auto
  /// pipeline). The rider already sees it in history.
  recorded,

  /// A stretch of a background detection that no recorded ride covers — riding
  /// the rider forgot to record.
  detected,
}

/// One stretch of riding, as input to [summarizeDay].
class DaySegment {
  final DaySegmentSource source;
  final DateTime start;
  final DateTime end;
  final double distanceM;
  final int movingSeconds;

  /// Ride-clock seconds. For a recorded ride this excludes paused time; for a
  /// detected segment it is first fix → last fix.
  final int durationSeconds;
  final double maxSpeedMs;

  /// First/last coordinates, when known. Used to credit the straight-line
  /// distance crawled across a jam gap between two merged detected segments
  /// (the GPS stream is off between detections, so that crawl is otherwise
  /// lost). Null for recorded rides.
  final ({double lat, double lng})? startPoint;
  final ({double lat, double lng})? endPoint;

  const DaySegment({
    required this.source,
    required this.start,
    required this.end,
    required this.distanceM,
    required this.movingSeconds,
    required this.durationSeconds,
    required this.maxSpeedMs,
    this.startPoint,
    this.endPoint,
  });

  bool get isRecorded => source == DaySegmentSource.recorded;
}

/// Segments counted as one ride.
class RideCluster {
  final List<DaySegment> segments;
  const RideCluster(this.segments);

  DateTime get start => segments.first.start;
  DateTime get end => segments
      .map((s) => s.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  bool get hasRecorded => segments.any((s) => s.isRecorded);

  /// Segment distances plus, between two consecutive *detected* segments,
  /// the straight-line distance across the gap.
  double get distanceM {
    var total = 0.0;
    for (var i = 0; i < segments.length; i++) {
      total += segments[i].distanceM;
      if (i == 0) continue;
      final prev = segments[i - 1];
      final cur = segments[i];
      if (!prev.isRecorded &&
          !cur.isRecorded &&
          prev.endPoint != null &&
          cur.startPoint != null) {
        total += haversineMeters(prev.endPoint!.lat, prev.endPoint!.lng,
            cur.startPoint!.lat, cur.startPoint!.lng);
      }
    }
    return total;
  }

  int get movingSeconds =>
      segments.fold(0, (sum, s) => sum + s.movingSeconds);

  /// Each segment's ride clock plus the gaps bridged between them — the
  /// stationary time in a jam is ride time, which is the whole point.
  int get rideSeconds {
    var total = 0;
    for (var i = 0; i < segments.length; i++) {
      total += segments[i].durationSeconds;
      if (i == 0) continue;
      final gap = segments[i].start.difference(segments[i - 1].end).inSeconds;
      if (gap > 0) total += gap;
    }
    return total;
  }

  double get maxSpeedMs =>
      segments.fold(0.0, (m, s) => s.maxSpeedMs > m ? s.maxSpeedMs : m);

  /// Whether a cluster with no recorded ride in it is a ride at all — the
  /// reconciler's own false-positive gate, applied to the merged journey
  /// rather than to each fragment. A 200 m crawl between two jams fails the
  /// gate on its own and is still part of a real ride.
  bool get passesRideGate {
    if (hasRecorded) return true;
    return movingSeconds > 0 &&
        maxSpeedMs >= AutoRideReconciler.minPeakSpeedMs &&
        distanceM >= AutoRideReconciler.minDistanceM &&
        rideSeconds >= AutoRideReconciler.minDurationSeconds;
  }
}

/// One day's riding.
class DailyRideSummary {
  /// Local midnight of the day summarised.
  final DateTime day;

  /// Rides the rider recorded (each recorded ride is one ride, even when a
  /// forgotten fragment was folded into it).
  final int recordedRideCount;

  /// Rides the rider didn't record, after jam-gap merging.
  final int detectedRideCount;

  final double distanceM;
  final int rideSeconds;
  final int movingSeconds;

  /// How many detected fragments went into [detectedRideCount] (and into
  /// recorded rides they touched). Diagnostic; e.g. 5 fragments → 1 ride.
  final int detectedSegmentCount;

  const DailyRideSummary({
    required this.day,
    required this.recordedRideCount,
    required this.detectedRideCount,
    required this.distanceM,
    required this.rideSeconds,
    required this.movingSeconds,
    required this.detectedSegmentCount,
  });

  int get rideCount => recordedRideCount + detectedRideCount;
  bool get isEmpty => rideCount == 0;

  /// Stopped-while-riding time, via the same rule as a single ride's.
  int get jamSeconds =>
      jam.jamSeconds(durationSeconds: rideSeconds, movingSeconds: movingSeconds);
}

/// Groups [segments] into rides.
///
/// Chronological sweep. The next segment joins the current cluster when the
/// gap from the cluster's end is at most [mergeGap], **unless** both already
/// contain a recorded ride — two rides the rider deliberately recorded stay
/// two rides, however close together. A detected fragment next to a recorded
/// ride (the minute of riding before the rider tapped Start, say) is folded
/// into it rather than counted as a second ride.
List<RideCluster> clusterDaySegments(
  List<DaySegment> segments, {
  Duration mergeGap = SensorConstants.autoRideMergeGap,
}) {
  final sorted = [...segments]..sort((a, b) => a.start.compareTo(b.start));
  final clusters = <List<DaySegment>>[];
  for (final s in sorted) {
    if (clusters.isNotEmpty) {
      final current = clusters.last;
      final currentEnd = RideCluster(current).end;
      final gap = s.start.difference(currentEnd);
      final bothRecorded = s.isRecorded && current.any((c) => c.isRecorded);
      if (gap <= mergeGap && !bothRecorded) {
        current.add(s);
        continue;
      }
    }
    clusters.add([s]);
  }
  return [for (final c in clusters) RideCluster(c)];
}

/// Summarises [day] (any instant on it; local calendar day) from [segments].
///
/// Only segments starting on that day are considered. Detected-only clusters
/// that fail [RideCluster.passesRideGate] contribute nothing.
DailyRideSummary summarizeDay({
  required DateTime day,
  required List<DaySegment> segments,
  Duration mergeGap = SensorConstants.autoRideMergeGap,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final onDay = segments
      .where((s) => !s.start.isBefore(dayStart) && s.start.isBefore(dayEnd))
      .toList();

  var recorded = 0;
  var detected = 0;
  var distance = 0.0;
  var rideSeconds = 0;
  var moving = 0;
  var detectedSegments = 0;

  for (final c in clusterDaySegments(onDay, mergeGap: mergeGap)) {
    if (!c.passesRideGate) continue;
    if (c.hasRecorded) {
      recorded += c.segments.where((s) => s.isRecorded).length;
    } else {
      detected++;
    }
    detectedSegments += c.segments.where((s) => !s.isRecorded).length;
    distance += c.distanceM;
    rideSeconds += c.rideSeconds;
    moving += c.movingSeconds;
  }

  return DailyRideSummary(
    day: dayStart,
    recordedRideCount: recorded,
    detectedRideCount: detected,
    distanceM: distance,
    rideSeconds: rideSeconds,
    movingSeconds: moving,
    detectedSegmentCount: detectedSegments,
  );
}
