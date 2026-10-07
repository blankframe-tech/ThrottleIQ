import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'realtime_location.dart';
import 'realtime_store.dart';

/// How long a caller waits for a server ack before moving on. Matches the
/// outbox's per-attempt timeout.
const Duration kRealtimeAckTimeout = Duration(seconds: 8);

/// One raw fix offered to a [RealtimeLocationPublisher].
class LocationSample {
  const LocationSample({
    required this.lat,
    required this.lng,
    this.speedMs,
    this.headingDeg,
    this.accuracyM,
  });

  final double lat;
  final double lng;
  final double? speedMs;
  final double? headingDeg;
  final double? accuracyM;
}

/// Writes one rider's position to a single RTDB path, throttled.
///
/// Fixes are offered as fast as they arrive; a write goes out only when
/// [minInterval] has passed since the last one AND the rider moved at least
/// [minMoveMeters] — or [heartbeat] has passed, so a parked rider still reads
/// as present. Each write carries the next `seq`.
///
/// Writes are fire-and-forget: the RTDB SDK keeps them in order on its one
/// socket and queues them while offline, and an offline `set` future doesn't
/// complete until reconnect, so awaiting it would stall the caller for the
/// length of a tunnel. [stop] relies on that ordering — its `remove` is
/// issued after every `set`, so it always wins.
class RealtimeLocationPublisher {
  RealtimeLocationPublisher({
    required RealtimeStore store,
    required this.path,
    required this.minInterval,
    this.minMoveMeters = 0,
    this.heartbeat,
    DateTime Function()? clock,
    this.onAck,
  })  : _store = store,
        _clock = clock ?? DateTime.now;

  final RealtimeStore _store;
  final String path;
  final Duration minInterval;
  final double minMoveMeters;
  final Duration? heartbeat;
  final DateTime Function() _clock;

  /// Called with each write's round-trip (issue → server ack). Feeds
  /// `RealtimeHealthMonitor`.
  final void Function(Duration latency)? onAck;

  static const Distance _distance = Distance();

  int _seq = 0;
  LatLng? _lastSent;
  DateTime? _lastSentAt;
  bool _stopped = false;
  int _writesIssued = 0;
  int _writesFailed = 0;

  bool get isStopped => _stopped;

  /// Next `seq` to be written; equals the number of writes issued.
  int get nextSeq => _seq;
  int get writesIssued => _writesIssued;
  int get writesFailed => _writesFailed;

  /// Offers a fix. Returns true when it was written.
  bool offer(LocationSample sample) {
    if (_stopped || !_store.isEnabled) return false;
    final now = _clock();
    final here = LatLng(sample.lat, sample.lng);
    if (!_isDue(here, now)) return false;

    final location = RealtimeLocation(
      lat: sample.lat,
      lng: sample.lng,
      seq: _seq++,
      speedMs: sample.speedMs,
      headingDeg: sample.headingDeg,
      accuracyM: sample.accuracyM,
    );
    _lastSent = here;
    _lastSentAt = now;
    _writesIssued++;

    final issuedAt = _clock();
    unawaited(_store.set(path, location.toWrite()).then((_) {
      onAck?.call(_clock().difference(issuedAt));
    }).catchError((Object e) {
      _writesFailed++;
      debugPrint('[Realtime] write to $path failed: $e');
    }));
    return true;
  }

  bool _isDue(LatLng here, DateTime now) {
    final lastAt = _lastSentAt;
    final last = _lastSent;
    if (lastAt == null || last == null) return true;
    final since = now.difference(lastAt);
    if (since < minInterval) return false;
    final hb = heartbeat;
    if (hb != null && since >= hb) return true;
    return _distance.as(LengthUnit.Meter, last, here) >= minMoveMeters;
  }

  /// Stops publishing for good. With [remove], deletes [path] (or
  /// [removePath], when the node to clear is a parent of [path]) so readers
  /// stop seeing the marker. Never throws, and never waits longer than
  /// [kRealtimeAckTimeout]: offline, the remove stays queued in the SDK and
  /// lands on reconnect, but the caller moves on.
  Future<void> stop({bool remove = true, String? removePath}) async {
    if (_stopped) return;
    _stopped = true;
    if (!remove || !_store.isEnabled) return;
    try {
      await _store.remove(removePath ?? path).timeout(kRealtimeAckTimeout);
    } on TimeoutException {
      debugPrint('[Realtime] remove of ${removePath ?? path} not acked yet — '
          'queued until reconnect');
    } catch (e) {
      debugPrint('[Realtime] remove of ${removePath ?? path} failed: $e');
    }
  }
}
