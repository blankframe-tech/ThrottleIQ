import 'dart:async';
import 'dart:math' as math;

import 'realtime_store.dart';

/// How long the socket may be down before features fall back to Firestore.
/// A tunnel or a cell handover shouldn't flip transports; a dead connection
/// should.
const Duration kRealtimeFallbackAfter = Duration(seconds: 15);

/// Which channel a feature should trust right now.
enum RealtimeTransport {
  /// RTDB is up: publish at the fast cadence, demote Firestore to heartbeat.
  realtime,

  /// RTDB is unconfigured, not yet connected, or down past the grace period:
  /// Firestore at its original cadence.
  fallback,
}

/// The fallback policy, pure so it can be tested exhaustively.
///
/// Conservative at startup: until the socket has come up at least once,
/// it's [RealtimeTransport.fallback] — Firestore keeps carrying positions
/// rather than betting on a connection that may never arrive.
RealtimeTransport chooseRealtimeTransport({
  required bool enabled,
  required bool connected,
  required DateTime now,
  DateTime? lastConnectedAt,
  Duration grace = kRealtimeFallbackAfter,
}) {
  if (!enabled) return RealtimeTransport.fallback;
  if (connected) return RealtimeTransport.realtime;
  if (lastConnectedAt != null && now.difference(lastConnectedAt) < grace) {
    return RealtimeTransport.realtime;
  }
  return RealtimeTransport.fallback;
}

/// A snapshot of how the RTDB channel is doing on this device.
class RealtimeHealth {
  const RealtimeHealth({
    required this.enabled,
    required this.connected,
    required this.transport,
    this.lastConnectedAt,
    this.connectCount = 0,
    this.ackCount = 0,
    this.lastAckLatency,
    this.p95AckLatency,
  });

  static const RealtimeHealth disabled = RealtimeHealth(
    enabled: false,
    connected: false,
    transport: RealtimeTransport.fallback,
  );

  final bool enabled;
  final bool connected;
  final RealtimeTransport transport;
  final DateTime? lastConnectedAt;

  /// Times `.info/connected` went true — >1 means the socket reconnected.
  final int connectCount;
  final int ackCount;
  final Duration? lastAckLatency;
  final Duration? p95AckLatency;

  bool get isRealtime => transport == RealtimeTransport.realtime;

  @override
  String toString() => 'RealtimeHealth(enabled: $enabled, connected: '
      '$connected, transport: ${transport.name}, connects: $connectCount, '
      'acks: $ackCount, lastAck: ${lastAckLatency?.inMilliseconds}ms, '
      'p95: ${p95AckLatency?.inMilliseconds}ms)';
}

/// The runtime verification layer: watches `.info/connected` and write-ack
/// latency, and decides [RealtimeTransport] for every feature.
///
/// A feature asks [transportNow] each time it's about to publish, so a
/// connection that dies mid-ride moves it back to Firestore within
/// [grace] without anyone restarting anything.
class RealtimeHealthMonitor {
  RealtimeHealthMonitor(
    this._store, {
    this.grace = kRealtimeFallbackAfter,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RealtimeStore _store;
  final Duration grace;
  final DateTime Function() _clock;

  final _controller = StreamController<RealtimeHealth>.broadcast();
  StreamSubscription<bool>? _connectedSub;
  bool _connected = false;
  DateTime? _lastConnectedAt;
  int _connectCount = 0;

  /// Most recent ack latencies, newest last; bounded.
  final List<Duration> _acks = [];
  int _ackCount = 0;
  static const int _ackWindow = 50;

  Stream<RealtimeHealth> get changes => _controller.stream;

  /// Subscribes to `.info/connected`. Idempotent. Note that subscribing is
  /// itself a reason for the SDK to connect, which is why it's only started
  /// while a `RealtimeLease` is held (see `realtimeHealthProvider`).
  void start() {
    if (_connectedSub != null || !_store.isEnabled) return;
    _connectedSub = _store.watchConnected().listen((connected) {
      final now = _clock();
      if (connected && !_connected) _connectCount++;
      // While connected, "last connected" is now; freeze it on disconnect so
      // the grace period counts from the moment the socket dropped.
      if (connected || _connected) _lastConnectedAt = now;
      _connected = connected;
      _emit();
    }, onError: (Object _) {
      _connected = false;
      _emit();
    });
  }

  void recordAck(Duration latency) {
    _ackCount++;
    _acks.add(latency);
    if (_acks.length > _ackWindow) _acks.removeAt(0);
    _emit();
  }

  RealtimeTransport transportNow() => chooseRealtimeTransport(
        enabled: _store.isEnabled,
        connected: _connected,
        now: _clock(),
        lastConnectedAt: _lastConnectedAt,
        grace: grace,
      );

  RealtimeHealth get current {
    if (!_store.isEnabled) return RealtimeHealth.disabled;
    return RealtimeHealth(
      enabled: true,
      connected: _connected,
      transport: transportNow(),
      lastConnectedAt: _lastConnectedAt,
      connectCount: _connectCount,
      ackCount: _ackCount,
      lastAckLatency: _acks.isEmpty ? null : _acks.last,
      p95AckLatency: _percentile(_acks, 0.95),
    );
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(current);
  }

  Future<void> dispose() async {
    await _connectedSub?.cancel();
    _connectedSub = null;
    await _controller.close();
  }
}

Duration? _percentile(List<Duration> values, double p) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final index = math.min(sorted.length - 1, (p * sorted.length).ceil() - 1);
  return sorted[math.max(0, index)];
}

/// Reader-side delivery check for one movement channel: counts, per writer,
/// how many updates arrived, how many were skipped (a `seq` jump) and how
/// many arrived out of order.
///
/// RTDB delivers the latest *value*, not every write — a reader that falls
/// behind legitimately sees `seq` jump. So [missed] is "updates this reader
/// never saw", a smoothness measure rather than a data-loss alarm; any
/// [outOfOrder] at all is a real bug.
class RealtimeDeliveryStats {
  final Map<String, int> _lastSeq = {};
  int received = 0;
  int missed = 0;
  int outOfOrder = 0;
  int restarts = 0;

  /// Records [seq] from [writer]. Returns false for a stale/out-of-order
  /// update the caller should ignore.
  bool observe(String writer, int seq) {
    final last = _lastSeq[writer];
    if (last != null && seq == last) return false; // re-delivery of same value
    received++;
    if (last == null) {
      _lastSeq[writer] = seq;
      return true;
    }
    if (seq == 0) {
      // The writer started a fresh publisher (rejoined, re-shared).
      restarts++;
      _lastSeq[writer] = seq;
      return true;
    }
    if (seq < last) {
      outOfOrder++;
      return false;
    }
    missed += seq - last - 1;
    _lastSeq[writer] = seq;
    return true;
  }

  void forget(String writer) => _lastSeq.remove(writer);

  @override
  String toString() => 'RealtimeDeliveryStats(received: $received, missed: '
      '$missed, outOfOrder: $outOfOrder, restarts: $restarts)';
}
