import 'dart:async';

import 'package:flutter/foundation.dart';

import 'realtime_store.dart';

/// How long the socket stays up after the last user releases it. Long enough
/// that hopping between the group map and the ride cockpit doesn't reconnect
/// every time.
const Duration kRealtimeLinger = Duration(seconds: 30);

/// Ref-counts who needs the RTDB socket and keeps it closed otherwise.
///
/// The Spark plan caps RTDB at 100 simultaneous connections, and the SDK
/// never closes its socket on its own once something has touched a ref. So
/// every feature that uses RTDB holds a [RealtimeLease] for exactly as long as
/// it needs live data — sharing, the group map being open, a chat room being
/// open — and the socket goes offline [linger] after the last one is released.
class RealtimeConnectionManager {
  RealtimeConnectionManager(
    this._store, {
    this.linger = kRealtimeLinger,
    Timer Function(Duration, void Function())? timerFactory,
  }) : _timerFactory = timerFactory ?? Timer.new;

  final RealtimeStore _store;
  final Duration linger;
  final Timer Function(Duration, void Function()) _timerFactory;

  final Map<int, String> _holders = {};
  int _nextId = 0;
  Timer? _offlineTimer;
  bool _online = false;

  /// Whether the socket has been asked to be up.
  bool get isOnline => _online;

  /// Tags of everyone currently holding a lease, for diagnostics.
  List<String> get holders => List.unmodifiable(_holders.values);

  RealtimeLease acquire(String tag) {
    final id = _nextId++;
    _holders[id] = tag;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    if (!_online && _store.isEnabled) {
      _online = true;
      unawaited(_store.goOnline().catchError(
          (Object e) => debugPrint('[Realtime] goOnline failed: $e')));
    }
    return RealtimeLease._(this, id);
  }

  void _release(int id) {
    if (_holders.remove(id) == null) return;
    if (_holders.isNotEmpty || !_online) return;
    _offlineTimer?.cancel();
    _offlineTimer = _timerFactory(linger, () {
      _offlineTimer = null;
      if (_holders.isNotEmpty) return;
      _online = false;
      unawaited(_store.goOffline().catchError(
          (Object e) => debugPrint('[Realtime] goOffline failed: $e')));
    });
  }

  void dispose() {
    _offlineTimer?.cancel();
    _offlineTimer = null;
  }
}

/// One holder's claim on the RTDB socket. [release] is idempotent.
class RealtimeLease {
  RealtimeLease._(this._manager, this._id);

  final RealtimeConnectionManager _manager;
  final int _id;
  bool _released = false;

  bool get isReleased => _released;

  void release() {
    if (_released) return;
    _released = true;
    _manager._release(_id);
  }
}
