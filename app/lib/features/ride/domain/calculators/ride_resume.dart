import '../../../../core/constants/sensor_constants.dart';
import '../../../../core/utils/geo_math.dart';
import 'average_speed.dart';
import 'fix_kinematics.dart';

/// One GPS fix as it comes back off disk — the only columns the resume path
/// needs out of a `ride_points` row.
typedef StoredFix = ({DateTime time, double lat, double lng, double speedMs});

/// The running totals a recording session keeps in memory, rebuilt from the
/// fixes that actually reached disk.
///
/// These live only in [RideRecordingNotifier]'s fields during a ride, so a
/// process death takes them with it. Everything here is derivable from the
/// persisted points, which is what makes a killed ride resumable rather than
/// merely salvageable: resume with these restored and the rider's distance,
/// top speed and average keep counting from where they were instead of
/// restarting at zero.
///
/// Event counts (hard brake / rapid accel / high jerk) are deliberately absent
/// — they come from [EventDetector]'s live jerk thresholds over a continuous
/// sample stream, and a thinned, already-persisted point list can't honestly
/// reproduce them. They stay at 0 through a resume, which is a real and
/// documented gap rather than a guessed-at number.
class RideResumeAggregates {
  final double distanceM;
  final double maxSpeedMs;

  /// Sum and count of the stored speed samples — the fallback average for a
  /// ride that never accumulated any moving time.
  final double speedSum;
  final int speedCount;

  /// Seconds spent above the moving threshold, by the same definition
  /// [movingSeconds] applies live. This is the denominator of the reported
  /// average speed, so rebuilding it here is what keeps a resumed ride's
  /// average directly comparable to one recorded in a single sitting.
  final int movingSeconds;

  final DateTime? firstFixTime;
  final DateTime? lastFixTime;

  const RideResumeAggregates({
    required this.distanceM,
    required this.maxSpeedMs,
    required this.speedSum,
    required this.speedCount,
    required this.movingSeconds,
    required this.firstFixTime,
    required this.lastFixTime,
  });

  static const empty = RideResumeAggregates(
    distanceM: 0,
    maxSpeedMs: 0,
    speedSum: 0,
    speedCount: 0,
    movingSeconds: 0,
    firstFixTime: null,
    lastFixTime: null,
  );

  /// Wall-clock span covered by the stored fixes. Used only as the fallback
  /// ride clock when no elapsed snapshot survived (see
  /// `RideRecordingNotifier.restoreInterruptedRide`) — it over-reports a ride
  /// that spent time paused, which is why the snapshot is preferred.
  Duration get span => (firstFixTime == null || lastFixTime == null)
      ? Duration.zero
      : lastFixTime!.difference(firstFixTime!);
}

/// Rebuilds [RideResumeAggregates] from [fixes], which must be in
/// chronological order (`RidePointDao.getForRide` returns them that way).
///
/// [segmentStartIndices] are the indices of fixes persisted with
/// `segment_start = 1` — the first fix after a resume (§90.C6). The gap
/// *into* such a fix is a pause, so it adds no distance and no moving time,
/// exactly as `_onPosition` skips the first delta after a resume. Without it a
/// rider who paused, vanned the bike and was then killed got the van journey
/// back on restore.
///
/// The other live rules are mirrored as closely as thinned, persisted points
/// allow (§90.C6/C12):
/// - a segment between two fixes the live path stored as stationary
///   (`speed_ms == 0`, i.e. rejected/idle) adds nothing — that is the
///   below-threshold jitter `_onPosition` zeroes;
/// - a segment's distance is capped at `max(v1, v2) · dt · 1.5 + accuracy`,
///   the same Doppler cap the live path applies per fix.
///
/// A ride whose stored fixes carry no speed at all (legacy rows) keeps the
/// old haversine sum, minus stationary jitter, so it isn't rebuilt to zero.
RideResumeAggregates rebuildRideAggregates(
  List<StoredFix> fixes, {
  Set<int> segmentStartIndices = const {},
}) {
  if (fixes.isEmpty) return RideResumeAggregates.empty;

  var distanceM = 0.0;
  var maxSpeedMs = 0.0;
  var speedSum = 0.0;
  var validSpeedCount = 0;

  final hasSpeedInfo = fixes.any((f) => f.speedMs > 0);

  for (var i = 0; i < fixes.length; i++) {
    final speed = fixes[i].speedMs;
    if (speed.isFinite && speed >= 0 && speed <= SensorConstants.maxPlausibleSpeedMs) {
      speedSum += speed;
      validSpeedCount++;
      if (speed > maxSpeedMs) maxSpeedMs = speed;
    }
    if (i > 0 && !segmentStartIndices.contains(i)) {
      distanceM += _segmentDistance(fixes[i - 1], fixes[i], hasSpeedInfo);
    }
  }

  // If stored fixes lacked Doppler speed (speedMs == 0), derive from consecutive fixes
  if (maxSpeedMs <= 0 && distanceM > 0 && fixes.length >= 2) {
    var derivedSum = 0.0;
    var derivedCount = 0;
    for (var i = 1; i < fixes.length; i++) {
      if (segmentStartIndices.contains(i)) continue;
      final dt = fixes[i].time.difference(fixes[i - 1].time).inMilliseconds / 1000.0;
      if (dt >= 0.1) {
        final d = haversineMeters(
          fixes[i - 1].lat,
          fixes[i - 1].lng,
          fixes[i].lat,
          fixes[i].lng,
        );
        // Ignore stationary jitter (< 1.5m)
        if (d < 1.5) continue;
        final derived = d / dt;
        if (derived <= SensorConstants.maxPlausibleSpeedMs) {
          derivedSum += derived;
          derivedCount++;
          if (derived > maxSpeedMs) maxSpeedMs = derived;
        }
      }
    }
    if (derivedCount > 0) {
      speedSum = derivedSum;
      validSpeedCount = derivedCount;
    }
  }

  // Moving time per segment, so a pause gap is never credited.
  var movingSecs = 0;
  var segStart = 0;
  for (var i = 1; i <= fixes.length; i++) {
    if (i == fixes.length || segmentStartIndices.contains(i)) {
      movingSecs += movingSeconds([
        for (final f in fixes.sublist(segStart, i))
          (time: f.time, speedMs: f.speedMs),
      ]);
      segStart = i;
    }
  }

  return RideResumeAggregates(
    distanceM: distanceM,
    maxSpeedMs: maxSpeedMs,
    speedSum: speedSum,
    speedCount: validSpeedCount > 0 ? validSpeedCount : fixes.length,
    movingSeconds: movingSecs,
    firstFixTime: fixes.first.time,
    lastFixTime: fixes.last.time,
  );
}

double _segmentDistance(StoredFix a, StoredFix b, bool hasSpeedInfo) {
  final d = haversineMeters(a.lat, a.lng, b.lat, b.lng);
  if (!hasSpeedInfo) {
    // Legacy rows with no speed column worth trusting: the old sum, minus
    // stationary drift.
    return d < 1.5 ? 0 : d;
  }
  if (a.speedMs <= 0 && b.speedMs <= 0) return 0;
  final dt = b.time.difference(a.time).inMilliseconds / 1000.0;
  final cap = dopplerDistanceCapM(
    rawSpeedMs: b.speedMs,
    prevSpeedMs: a.speedMs,
    deltaTSeconds: dt,
    accuracyM: SensorConstants.maxGpsAccuracyM,
  );
  return d > cap ? cap : d;
}
