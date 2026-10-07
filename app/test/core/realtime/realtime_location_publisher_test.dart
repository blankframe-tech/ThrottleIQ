import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_location.dart';
import 'package:throttleiq/core/realtime/realtime_location_publisher.dart';

import 'fake_clock.dart';
import 'in_memory_realtime_store.dart';

/// The writer side of every movement channel: throttling, seq, and the
/// "stop always wins" ordering the live-share revoke depends on.
void main() {
  late FakeClock clock;
  late InMemoryRealtimeStore store;

  const path = 'live_shares/T/location';
  const dhaka = LocationSample(lat: 23.8103, lng: 90.4125, speedMs: 8);
  // ~11 m north of [dhaka].
  const nudged = LocationSample(lat: 23.8104, lng: 90.4125, speedMs: 8);

  RealtimeLocationPublisher publisher({
    Duration minInterval = const Duration(milliseconds: 900),
    double minMoveMeters = 0,
    Duration? heartbeat,
    void Function(Duration)? onAck,
  }) =>
      RealtimeLocationPublisher(
        store: store,
        path: path,
        minInterval: minInterval,
        minMoveMeters: minMoveMeters,
        heartbeat: heartbeat,
        clock: clock.call,
        onAck: onAck,
      );

  setUp(() {
    clock = FakeClock();
    store = InMemoryRealtimeStore(serverClock: clock.call);
  });

  test('the first fix is written immediately with seq 0 and a server ts',
      () async {
    final p = publisher();
    expect(p.offer(dhaka), isTrue);
    await pumpEventQueue();

    final written = RealtimeLocation.tryParse(store.valueAt(path));
    expect(written, isNotNull);
    expect(written!.seq, 0);
    expect(written.lat, dhaka.lat);
    expect(written.serverTime, clock.now);
  });

  test('throttles to minInterval: 1 Hz fixes at 900 ms gate every one', () {
    final p = publisher();
    var written = 0;
    for (var i = 0; i < 10; i++) {
      if (p.offer(dhaka)) written++;
      clock.elapse(const Duration(seconds: 1));
    }
    expect(written, 10);
  });

  test('fixes faster than minInterval are dropped, not queued', () {
    final p = publisher();
    var written = 0;
    for (var i = 0; i < 10; i++) {
      if (p.offer(dhaka)) written++;
      clock.elapse(const Duration(milliseconds: 200));
    }
    // t = 0, 1.0 s (5 × 200 ms) → two writes in 2 s of 5 Hz fixes.
    expect(written, 2);
    expect(p.nextSeq, 2);
  });

  test('minMoveMeters skips a parked rider until the heartbeat is due', () {
    final p = publisher(
      minInterval: const Duration(seconds: 2),
      minMoveMeters: 5,
      heartbeat: const Duration(seconds: 30),
    );
    expect(p.offer(dhaka), isTrue);
    clock.elapse(const Duration(seconds: 3));
    expect(p.offer(dhaka), isFalse, reason: 'not moved, heartbeat not due');
    clock.elapse(const Duration(seconds: 3));
    expect(p.offer(nudged), isTrue, reason: 'moved ~11 m');
    clock.elapse(const Duration(seconds: 29));
    expect(p.offer(nudged), isFalse);
    clock.elapse(const Duration(seconds: 1));
    expect(p.offer(nudged), isTrue, reason: '30 s heartbeat');
  });

  test('seq is strictly +1 per write — the reader-side gap detector relies on it',
      () async {
    final p = publisher();
    final seen = <int>[];
    final sub = store.watch(path).listen((raw) {
      final loc = RealtimeLocation.tryParse(raw);
      if (loc != null) seen.add(loc.seq);
    });
    for (var i = 0; i < 5; i++) {
      p.offer(dhaka);
      clock.elapse(const Duration(seconds: 1));
      await pumpEventQueue();
    }
    await sub.cancel();
    expect(seen, [0, 1, 2, 3, 4]);
  });

  test('offline: offer never blocks, writes queue and land in order on reconnect',
      () async {
    store.setOnline(false);
    final p = publisher();
    for (var i = 0; i < 3; i++) {
      expect(p.offer(dhaka), isTrue);
      clock.elapse(const Duration(seconds: 1));
    }
    expect(store.pendingWrites, 3);
    expect(store.valueAt(path), isNull);

    store.setOnline(true);
    await pumpEventQueue();
    expect(store.log.map((o) => (o.value as Map)['seq']), [0, 1, 2]);
  });

  test('stop() removes the node and its remove lands after every queued set',
      () async {
    store.setOnline(false);
    final p = publisher();
    p.offer(dhaka);
    clock.elapse(const Duration(seconds: 1));
    p.offer(dhaka);
    final stopped = p.stop(removePath: 'live_shares/T');

    store.setOnline(true);
    await stopped;
    expect(store.log.map((o) => o.kind), ['set', 'set', 'remove']);
    expect(store.valueAt('live_shares/T'), isNull);

    clock.elapse(const Duration(seconds: 5));
    expect(p.offer(dhaka), isFalse, reason: 'nothing after stop');
    expect(store.log.length, 3);
  });

  test('stop() does not hang when the remove is never acked', () async {
    store.setOnline(false);
    final p = publisher();
    p.offer(dhaka);
    // Real 8 s timeout would make this slow; the contract under test is
    // only that stop() returns at all while offline.
    await expectLater(
      p.stop().timeout(const Duration(seconds: 10)),
      completes,
    );
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('reports ack latency for every acknowledged write', () async {
    final acks = <Duration>[];
    final p = publisher(onAck: acks.add);
    p.offer(dhaka);
    clock.elapse(const Duration(seconds: 1));
    p.offer(dhaka);
    await pumpEventQueue();
    expect(acks, hasLength(2));
  });

  test('a rejected write is counted, never thrown', () async {
    store.denyPaths.add('live_shares/');
    final p = publisher();
    expect(p.offer(dhaka), isTrue);
    await pumpEventQueue();
    expect(p.writesFailed, 1);
  });

  test('disabled store: nothing is written', () {
    store = InMemoryRealtimeStore(enabled: false);
    final p = publisher();
    expect(p.offer(dhaka), isFalse);
    expect(store.log, isEmpty);
  });
}
