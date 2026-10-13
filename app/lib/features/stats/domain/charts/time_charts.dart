/// Time on the road: moving vs stopped, and time stuck in jams.
library;

import '../../../ride/domain/entities/ride_entity.dart';
import '../ride_analytics.dart';

abstract final class TimeCharts {
  /// value = moving share; secondary = stopped minutes, so the table and
  /// CSV can show both halves of the bar.
  static const movingVsStopped = PerRideChart(
    'movingVsStopped',
    value: movingSharePercent,
    secondary: _stoppedMin,
    aggregation: Aggregation.mean,
    shapeInsight: _stoppedShare,
  );
  static const jamTime = PerRideChart(
    'jamTime',
    value: _stoppedMin,
    shapeInsight: _stoppedShare,
  );

  static const List<AnalyticsChart> all = [movingVsStopped, jamTime];
}

/// Share of the riding clock spent stopped, in percent.
const stoppedShareInsight = InsightKind('stoppedShare');

/// Seconds the ride spent stopped while recording, or null when unknown.
int? stoppedSeconds(RideEntity r) => r.jamSeconds;

/// Share of the ride clock spent moving, 0–100, or null when unknown.
double? movingSharePercent(RideEntity r) {
  final d = r.durationSeconds;
  final m = r.movingSeconds;
  if (d == null || m == null || d <= 0) return null;
  final share = m / d * 100;
  return share.clamp(0, 100).toDouble();
}

/// Moving and stopped minutes of a ride, for the stacked bar. Null when
/// either is unknown.
({double movingMin, double stoppedMin})? movingStoppedMinutes(RideEntity r) {
  final m = r.movingSeconds;
  final s = stoppedSeconds(r);
  if (m == null || s == null) return null;
  return (movingMin: m / 60, stoppedMin: s / 60);
}

double? _stoppedMin(RideEntity r) {
  final s = stoppedSeconds(r);
  return s == null ? null : s / 60;
}

List<AnalyticsInsight> _stoppedShare(
  List<RideEntity> rides,
  List<AnalyticsPoint> series,
) {
  var dur = 0;
  var stopped = 0;
  for (final r in rides) {
    final s = stoppedSeconds(r);
    final d = r.durationSeconds;
    if (s == null || d == null || d <= 0) continue;
    dur += d;
    stopped += s;
  }
  return [
    if (dur > 0)
      AnalyticsInsight(stoppedShareInsight, value: stopped / dur * 100),
  ];
}
