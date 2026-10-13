import 'package:latlong2/latlong.dart';

/// How often the group map checks whether to publish this device's position.
///
/// Was 5 s, unconditionally (issues §90.A2): 5 riders × 2 h ≈ 7,200 writes
/// (36 % of the Spark plan's 20k/day) and ≈ 36,000 listener reads, even
/// with everyone parked at a tea stall. 20 s is still plenty for "roughly
/// where is everyone".
const Duration kGroupRideBroadcastInterval = Duration(seconds: 20);

/// Below this movement since the last publish, a tick is skipped…
const double kGroupRideMinMoveMeters = 25;

/// …unless this long has passed since the last publish: a heartbeat so a
/// stationary rider still reads as present rather than stale.
const Duration kGroupRideBroadcastHeartbeat = Duration(minutes: 2);

/// Past this age a member's position is shown as stale rather than current.
/// One heartbeat plus two broadcast ticks of slack — a rider who is parked
/// (publishing only every [kGroupRideBroadcastHeartbeat]) must not flicker
/// stale between heartbeats, and one dropped write shouldn't flag them.
const Duration kGroupRideStaleAfter = Duration(seconds: 160);

const Distance _distance = Distance();

/// Whether this tick should publish [current].
///
/// Always on the first publish; otherwise when the rider moved at least
/// [minMoveMeters] since [lastSent], or [heartbeat] has elapsed since
/// [lastSentAt].
bool shouldBroadcastPosition({
  required LatLng current,
  required DateTime now,
  LatLng? lastSent,
  DateTime? lastSentAt,
  double minMoveMeters = kGroupRideMinMoveMeters,
  Duration heartbeat = kGroupRideBroadcastHeartbeat,
}) {
  if (lastSent == null || lastSentAt == null) return true;
  if (now.difference(lastSentAt) >= heartbeat) return true;
  return _distance.as(LengthUnit.Meter, lastSent, current) >= minMoveMeters;
}
