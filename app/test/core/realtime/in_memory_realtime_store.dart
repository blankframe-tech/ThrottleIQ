import 'dart:async';

import 'package:throttleiq/core/realtime/realtime_store.dart';

/// One operation the fake saw, in the order the "server" applied it.
class RealtimeOp {
  RealtimeOp(this.kind, this.path, [this.value]);

  final String kind; // 'set' | 'remove'
  final String path;
  final Object? value;

  @override
  String toString() => '$kind $path${value == null ? '' : ' $value'}';
}

/// A [RealtimeStore] that behaves like the RTDB SDK in the ways the app
/// depends on, without a socket:
///
/// - one ordered write queue: while [online] is false, writes are held and
///   their futures stay pending; [setOnline] (true) applies them in issue
///   order and completes them — what makes "remove after set always wins"
///   testable;
/// - `{'.sv': 'timestamp'}` is resolved to [serverNow] at apply time;
/// - `onDisconnect().remove()` registrations run on [setOnline] (false);
/// - [watch] emits the current value on listen and after every change under
///   (or above) the watched path;
/// - [denyPaths]: any write/watch under these prefixes fails with
///   [permissionDenied], like a rules rejection.
class InMemoryRealtimeStore implements RealtimeStore {
  InMemoryRealtimeStore({
    this.enabled = true,
    bool online = true,
    DateTime Function()? serverClock,
  })  : _online = online,
        _serverClock = serverClock ?? DateTime.now;

  final bool enabled;
  final DateTime Function() _serverClock;
  bool _online;

  final Map<String, Object?> _root = {};
  final List<RealtimeOp> log = [];
  final List<_Pending> _queue = [];
  final Set<String> _onDisconnect = {};
  final Set<String> denyPaths = {};
  final _connected = StreamController<bool>.broadcast();
  final List<_Watcher> _watchers = [];
  int goOnlineCalls = 0;
  int goOfflineCalls = 0;
  int serverTimeOffsetMs = 0;

  static final Exception permissionDenied =
      Exception('permission-denied (fake rules)');

  DateTime get serverNow => _serverClock();
  bool get online => _online;
  Set<String> get onDisconnectPaths => Set.unmodifiable(_onDisconnect);
  int get pendingWrites => _queue.length;

  /// Current value at [path], decoded like the plugin returns it.
  Object? valueAt(String path) => _read(_split(path));

  @override
  bool get isEnabled => enabled;

  @override
  Future<void> set(String path, Object value) =>
      _enqueue(RealtimeOp('set', path, value));

  @override
  Future<void> remove(String path) => _enqueue(RealtimeOp('remove', path));

  Future<void> _enqueue(RealtimeOp op) {
    if (_denied(op.path)) return Future.error(permissionDenied);
    final pending = _Pending(op);
    _queue.add(pending);
    if (_online) _flush();
    return pending.completer.future;
  }

  void _flush() {
    while (_queue.isNotEmpty) {
      final p = _queue.removeAt(0);
      _apply(p.op);
      p.completer.complete();
    }
  }

  void _apply(RealtimeOp op) {
    final segments = _split(op.path);
    if (op.kind == 'remove') {
      _write(segments, null);
      log.add(op);
    } else {
      final resolved = _resolve(op.value);
      _write(segments, resolved);
      log.add(RealtimeOp('set', op.path, resolved));
    }
    _notify(op.path);
  }

  Object? _resolve(Object? v) {
    if (v is Map) {
      if (v.length == 1 && v['.sv'] == 'timestamp') {
        return serverNow.millisecondsSinceEpoch;
      }
      return {for (final e in v.entries) e.key.toString(): _resolve(e.value)};
    }
    return v;
  }

  void _write(List<String> segments, Object? value) {
    if (segments.isEmpty) return;
    var node = _root;
    for (final s in segments.take(segments.length - 1)) {
      final next = node[s];
      if (next is Map<String, Object?>) {
        node = next;
      } else {
        if (value == null) return;
        final created = <String, Object?>{};
        node[s] = created;
        node = created;
      }
    }
    if (value == null) {
      node.remove(segments.last);
    } else {
      node[segments.last] = _deepCopy(value);
    }
    _prune(_root);
  }

  /// RTDB has no empty nodes.
  void _prune(Map<String, Object?> node) {
    for (final key in node.keys.toList()) {
      final child = node[key];
      if (child is Map<String, Object?>) {
        _prune(child);
        if (child.isEmpty) node.remove(key);
      }
    }
  }

  Object? _read(List<String> segments) {
    Object? node = _root;
    for (final s in segments) {
      if (node is! Map) return null;
      node = node[s];
    }
    if (node is Map && node.isEmpty) return null;
    return _deepCopy(node);
  }

  Object? _deepCopy(Object? v) => v is Map
      ? {for (final e in v.entries) e.key.toString(): _deepCopy(e.value)}
      : v;

  static List<String> _split(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  bool _denied(String path) => denyPaths.any((d) => path.startsWith(d));

  bool _related(String a, String b) =>
      a == b || a.startsWith('$b/') || b.startsWith('$a/');

  void _notify(String changedPath) {
    for (final w in List.of(_watchers)) {
      if (_related(w.path, changedPath)) w.emit(_read(_split(w.path)));
    }
  }

  @override
  Stream<Object?> watch(String path) {
    late _Watcher watcher;
    final controller = StreamController<Object?>(
      onListen: () {
        if (_denied(path)) {
          watcher.controller.addError(permissionDenied);
          return;
        }
        _watchers.add(watcher);
        watcher.emit(_read(_split(path)));
      },
      onCancel: () => _watchers.remove(watcher),
    );
    watcher = _Watcher(path, controller);
    return controller.stream;
  }

  /// Simulates a rules change revoking a live listener (e.g. a kick).
  void revoke(String pathPrefix) {
    denyPaths.add(pathPrefix);
    for (final w in List.of(_watchers)) {
      if (w.path.startsWith(pathPrefix)) {
        w.controller.addError(permissionDenied);
        _watchers.remove(w);
      }
    }
  }

  @override
  Stream<bool> watchConnected() async* {
    yield _online;
    yield* _connected.stream;
  }

  @override
  Stream<int> watchServerTimeOffset() => Stream.value(serverTimeOffsetMs);

  @override
  Future<void> removeOnDisconnect(String path) async => _onDisconnect.add(path);

  @override
  Future<void> cancelOnDisconnect(String path) async =>
      _onDisconnect.remove(path);

  /// Socket up/down. Going down runs the onDisconnect removals server-side
  /// (as RTDB does); coming up flushes queued writes in order.
  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    if (!value) {
      for (final path in _onDisconnect.toList()) {
        _apply(RealtimeOp('remove', path));
      }
      _onDisconnect.clear();
    } else {
      _flush();
    }
    _connected.add(value);
  }

  @override
  Future<void> goOnline() async {
    goOnlineCalls++;
    setOnline(true);
  }

  @override
  Future<void> goOffline() async {
    goOfflineCalls++;
    setOnline(false);
  }
}

class _Pending {
  _Pending(this.op);
  final RealtimeOp op;
  final Completer<void> completer = Completer<void>();
}

class _Watcher {
  _Watcher(this.path, this.controller);
  final String path;
  final StreamController<Object?> controller;
  void emit(Object? v) {
    if (!controller.isClosed) controller.add(v);
  }
}
