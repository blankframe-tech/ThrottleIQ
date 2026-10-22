import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_broadcast_gate.dart';

/// The group-ride position publish gate (issues §90.A2).
void main() {
  const here = LatLng(23.8103, 90.4125);
  // ~11 m and ~111 m north of `here` (1e-4 / 1e-3 degrees of latitude).
  const near = LatLng(23.8104, 90.4125);
  const far = LatLng(23.8113, 90.4125);
  final t0 = DateTime(2026, 10, 6, 9);

  test('first publish always goes out', () {
    expect(shouldBroadcastPosition(current: here, now: t0), isTrue);
  });

  test('moving less than the threshold is skipped before the heartbeat', () {
    expect(
      shouldBroadcastPosition(
        current: near,
        now: t0.add(const Duration(seconds: 40)),
        lastSent: here,
        lastSentAt: t0,
      ),
      isFalse,
    );
  });

  test('moving past the threshold publishes', () {
    expect(
      shouldBroadcastPosition(
        current: far,
        now: t0.add(kGroupRideBroadcastInterval),
        lastSent: here,
        lastSentAt: t0,
      ),
      isTrue,
    );
  });

  test('a parked rider still heartbeats', () {
    expect(
      shouldBroadcastPosition(
        current: here,
        now: t0.add(kGroupRideBroadcastHeartbeat),
        lastSent: here,
        lastSentAt: t0,
      ),
      isTrue,
    );
  });

  test(
      'stale threshold outlasts a heartbeat plus a tick, so parked riders '
      "don't flicker stale", () {
    expect(
      kGroupRideStaleAfter >
          kGroupRideBroadcastHeartbeat + kGroupRideMaxBroadcastInterval,
      isTrue,
    );
  });

  test('bigger groups tick slower, so reads per minute grow with N, not N²',
      () {
    expect(groupRideBroadcastInterval(0), kGroupRideBroadcastInterval);
    expect(groupRideBroadcastInterval(3), kGroupRideBroadcastInterval);
    expect(groupRideBroadcastInterval(15), const Duration(seconds: 30));
    expect(groupRideBroadcastInterval(20), kGroupRideMaxBroadcastInterval);
    expect(groupRideBroadcastInterval(50), kGroupRideMaxBroadcastInterval);
    // Listener reads per minute: n writes × n listeners per tick.
    double readsPerMin(int n) =>
        n * n * 60 / groupRideBroadcastInterval(n).inSeconds;
    expect(readsPerMin(20) / readsPerMin(10), closeTo(2, 0.01));
  });

  test('interval is no faster than 15 s (Spark write budget)', () {
    expect(kGroupRideBroadcastInterval >= const Duration(seconds: 15), isTrue);
  });
}
