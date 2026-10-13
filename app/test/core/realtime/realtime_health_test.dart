import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';

import 'fake_clock.dart';
import 'in_memory_realtime_store.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 9);

  group('chooseRealtimeTransport', () {
    test('unconfigured RTDB is always fallback', () {
      expect(
        chooseRealtimeTransport(enabled: false, connected: true, now: t0),
        RealtimeTransport.fallback,
      );
    });

    test('connected is realtime', () {
      expect(
        chooseRealtimeTransport(enabled: true, connected: true, now: t0),
        RealtimeTransport.realtime,
      );
    });

    test('never connected yet is fallback — do not bet on a socket that may never come',
        () {
      expect(
        chooseRealtimeTransport(enabled: true, connected: false, now: t0),
        RealtimeTransport.fallback,
      );
    });

    test('a brief drop stays realtime; past the grace it falls back', () {
      RealtimeTransport at(Duration since) => chooseRealtimeTransport(
            enabled: true,
            connected: false,
            now: t0.add(since),
            lastConnectedAt: t0,
          );
      expect(at(const Duration(seconds: 14)), RealtimeTransport.realtime);
      expect(at(kRealtimeFallbackAfter), RealtimeTransport.fallback);
    });
  });

  group('RealtimeHealthMonitor', () {
    late FakeClock clock;
    late InMemoryRealtimeStore store;
    late RealtimeHealthMonitor monitor;

    setUp(() {
      clock = FakeClock(t0);
      store = InMemoryRealtimeStore(online: false);
      monitor = RealtimeHealthMonitor(store, clock: clock.call)..start();
    });

    tearDown(() => monitor.dispose());

    test('follows .info/connected through a drop, the grace, and a reconnect',
        () async {
      await pumpEventQueue();
      expect(monitor.transportNow(), RealtimeTransport.fallback);

      store.setOnline(true);
      await pumpEventQueue();
      expect(monitor.current.connected, isTrue);
      expect(monitor.transportNow(), RealtimeTransport.realtime);

      clock.elapse(const Duration(minutes: 3));
      store.setOnline(false);
      await pumpEventQueue();
      clock.elapse(const Duration(seconds: 10));
      expect(monitor.transportNow(), RealtimeTransport.realtime,
          reason: 'grace counts from the drop, not the first connect');
      clock.elapse(const Duration(seconds: 5));
      expect(monitor.transportNow(), RealtimeTransport.fallback);

      store.setOnline(true);
      await pumpEventQueue();
      expect(monitor.transportNow(), RealtimeTransport.realtime);
      expect(monitor.current.connectCount, 2);
    });

    test('ack latencies roll into last and p95', () {
      for (var ms = 10; ms <= 200; ms += 10) {
        monitor.recordAck(Duration(milliseconds: ms));
      }
      final h = monitor.current;
      expect(h.ackCount, 20);
      expect(h.lastAckLatency, const Duration(milliseconds: 200));
      expect(h.p95AckLatency, const Duration(milliseconds: 190));
    });

    test('emits a change on every transition', () async {
      await pumpEventQueue(); // the initial "not connected" reading
      final seen = <bool>[];
      final sub = monitor.changes.listen((h) => seen.add(h.connected));
      store.setOnline(true);
      await pumpEventQueue();
      store.setOnline(false);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [true, false]);
    });

    test('a disabled store reports the disabled snapshot', () {
      final m = RealtimeHealthMonitor(InMemoryRealtimeStore(enabled: false));
      expect(m.current.enabled, isFalse);
      expect(m.current.isRealtime, isFalse);
    });
  });

  group('RealtimeDeliveryStats', () {
    test('a clean 1-by-1 stream has no misses', () {
      final stats = RealtimeDeliveryStats();
      for (var i = 0; i < 10; i++) {
        expect(stats.observe('alice', i), isTrue);
      }
      expect(stats.received, 10);
      expect(stats.missed, 0);
      expect(stats.outOfOrder, 0);
    });

    test('a jump counts the skipped updates', () {
      final stats = RealtimeDeliveryStats()
        ..observe('alice', 0)
        ..observe('alice', 1)
        ..observe('alice', 5);
      expect(stats.missed, 3);
    });

    test('going backwards is out-of-order and rejected', () {
      final stats = RealtimeDeliveryStats()
        ..observe('alice', 4)
        ..observe('alice', 5);
      expect(stats.observe('alice', 3), isFalse);
      expect(stats.outOfOrder, 1);
    });

    test('seq 0 after progress is a restarted writer, not out-of-order', () {
      final stats = RealtimeDeliveryStats()
        ..observe('alice', 7)
        ..observe('alice', 0);
      expect(stats.restarts, 1);
      expect(stats.outOfOrder, 0);
    });

    test('re-delivery of the same value is ignored', () {
      final stats = RealtimeDeliveryStats()..observe('alice', 2);
      expect(stats.observe('alice', 2), isFalse);
      expect(stats.received, 1);
    });

    test('writers are tracked independently', () {
      final stats = RealtimeDeliveryStats()
        ..observe('alice', 0)
        ..observe('bob', 10)
        ..observe('alice', 1)
        ..observe('bob', 11);
      expect(stats.missed, 0);
      expect(stats.outOfOrder, 0);
    });
  });
}
