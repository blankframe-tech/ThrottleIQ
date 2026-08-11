import 'dart:math';

import 'average_speed.dart';

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
RideResumeAggregates rebuildRideAggregates(List<StoredFix> fixes) {
  if (fixes.isEmpty) return RideResumeAggregates.empty;

  var distanceM = 0.0;
  var maxSpeedMs = 0.0;
  var speedSum = 0.0;

  for (var i = 0; i < fixes.length; i++) {
    final speed = fixes[i].speedMs;
    speedSum += speed;
    if (speed > maxSpeedMs) maxSpeedMs = speed;
    if (i > 0) {
      distanceM += haversineMeters(
        lat1: fixes[i - 1].lat,
        lng1: fixes[i - 1].lng,
        lat2: fixes[i].lat,
        lng2: fixes[i].lng,
      );
    }
  }

  return RideResumeAggregates(
    distanceM: distanceM,
    maxSpeedMs: maxSpeedMs,
    speedSum: speedSum,
    speedCount: fixes.length,
    movingSeconds: movingSeconds(
      [for (final f in fixes) (time: f.time, speedMs: f.speedMs)],
    ),
    firstFixTime: fixes.first.time,
    lastFixTime: fixes.last.time,
  );
}

/// Great-circle distance between two WGS84 coordinates, in metres.
double haversineMeters({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const earthRadiusM = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusM * c;
}
