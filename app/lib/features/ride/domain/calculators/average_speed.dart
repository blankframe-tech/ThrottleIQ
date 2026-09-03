import '../../../../core/constants/sensor_constants.dart';

/// Average speed for a completed ride.
///
/// Deliberately **distance ÷ moving time**, not the mean of the per-fix speed
/// samples the app used to report. The old mean-of-samples number was
/// dragged toward zero by every fix taken at a red light: GPS keeps emitting
/// ~1 Hz while the bike sits still, so a commute with a lot of traffic
/// reported an average far below anything the rider experienced. Excluding
/// stopped time makes the figure mean "how fast was I actually going when I
/// was going", which is what riders read it as — and it matches how every
/// other tracking app defines it.
///
/// Pure so it can be tested directly; see `average_speed_test.dart`.
double averageSpeedMs({
  required double distanceM,
  required int movingSeconds,
  double? maxSpeedMs,
}) {
  if (movingSeconds <= 0 || distanceM <= 0) return 0;
  final speed = distanceM / movingSeconds;
  if (maxSpeedMs != null && maxSpeedMs > 0 && speed > maxSpeedMs) {
    return maxSpeedMs;
  }
  return speed;
}

/// A single GPS fix reduced to what the moving-time calculation needs.
typedef SpeedSample = ({DateTime time, double speedMs});

/// Milliseconds spent actually moving across [samples].
int movingMilliseconds(
  List<SpeedSample> samples, {
  double thresholdMs = SensorConstants.movingSpeedThresholdMs,
  int maxGapSeconds = 60,
}) {
  if (samples.length < 2) return 0;

  var totalMs = 0;
  final maxGapMs = maxGapSeconds * 1000;
  for (var i = 1; i < samples.length; i++) {
    if (samples[i].speedMs < thresholdMs) continue;

    final gapMs = samples[i].time.difference(samples[i - 1].time).inMilliseconds;
    if (gapMs <= 0 || gapMs > maxGapMs) continue;
    totalMs += gapMs;
  }
  return totalMs;
}

/// Seconds spent actually moving across [samples].
///
/// Sums the gap between consecutive fixes, counting a gap only when the fix
/// that *ends* it was above the moving threshold — the same
/// `speedMs < 1 => 'idle'` cutoff the recorder already stamps onto each
/// `ride_points` row as `period_type`, so this can never disagree with the
/// stored classification.
///
/// [maxGapSeconds] guards the pathological case: if tracking is suspended
/// (tunnel, app killed, phone asleep) the next fix can be minutes later, and
/// counting that whole gap as "moving" would inflate moving time and depress
/// the average. Gaps longer than this are ignored entirely rather than
/// guessed at.
int movingSeconds(
  List<SpeedSample> samples, {
  double thresholdMs = SensorConstants.movingSpeedThresholdMs,
  int maxGapSeconds = 60,
}) {
  final ms = movingMilliseconds(samples,
      thresholdMs: thresholdMs, maxGapSeconds: maxGapSeconds);
  return (ms / 1000).round();
}
