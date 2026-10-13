import 'dart:async';

/// A manual clock plus one-shot timers that fire when [elapse] passes their
/// deadline — enough to drive the realtime layer's throttles and lingers
/// without real waiting.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 10, 7, 9);

  DateTime now;
  final List<_FakeTimer> _timers = [];

  DateTime call() => now;

  Timer timer(Duration duration, void Function() callback) {
    final t = _FakeTimer(now.add(duration), callback, _timers);
    _timers.add(t);
    return t;
  }

  int get pendingTimers => _timers.where((t) => t.isActive).length;

  void elapse(Duration d) {
    final target = now.add(d);
    while (true) {
      final due = _timers.where((t) => t.isActive && !t.deadline.isAfter(target)).toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
      if (due.isEmpty) break;
      final next = due.first;
      now = next.deadline;
      next.fire();
    }
    now = target;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.deadline, this._callback, this._owner);

  final DateTime deadline;
  final void Function() _callback;
  final List<_FakeTimer> _owner;
  bool _active = true;

  void fire() {
    _active = false;
    _owner.remove(this);
    _callback();
  }

  @override
  void cancel() {
    _active = false;
    _owner.remove(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
