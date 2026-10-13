import 'dart:async';

/// The GPS/IMU subscriptions of one recording, owned as a set.
///
/// §90.C1: pausing used to call `.pause()` on these. They are broadcast
/// streams, so a paused subscription *buffers* every event (native GPS and
/// sensors keep running) and replays the whole backlog on `.resume()` — a
/// rider who paused, put the bike in a van and resumed had the van journey
/// counted as riding. Pausing now cancels the set; resuming opens a fresh one,
/// which never sees what happened in between.
///
/// §90.C5: [open] always cancels whatever is already open first, so a second
/// open (a double-tapped Resume that got past the in-flight guard, say) can
/// never leave a leaked listener behind keeping GPS and the foreground
/// notification alive after the ride ends.
class RecordingSubscriptions {
  final List<StreamSubscription<Object?>> _subs = [];

  /// Whether a set is currently open.
  bool get isOpen => _subs.isNotEmpty;

  /// Cancels any open set, then opens the subscriptions [opener] returns.
  void open(List<StreamSubscription<Object?>> Function() opener) {
    _cancelSync();
    _subs.addAll(opener());
  }

  /// Cancels and forgets every subscription. Safe to call when none are open.
  Future<void> cancel() async {
    final subs = List<StreamSubscription<Object?>>.from(_subs);
    _subs.clear();
    for (final s in subs) {
      await s.cancel();
    }
  }

  void _cancelSync() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }
}

/// A synchronous single-flight latch for ride transitions (start, pause,
/// resume, stop).
///
/// §90.C5: `resumeRide` read its guards before its first `await`, so two taps
/// landing together both passed them and each opened a full set of
/// subscriptions. [tryEnter] claims the latch *synchronously* — the second
/// caller sees it taken before either has awaited anything.
class TransitionLatch {
  bool _busy = false;

  bool get isBusy => _busy;

  /// Claims the latch. Returns false if a transition is already running.
  bool tryEnter() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void exit() => _busy = false;

  /// Claims the latch, waiting up to [timeout] for a transition already
  /// running to finish. For Stop/Discard: a rider ending the ride while a
  /// pause is still settling must not be told "nothing to stop".
  Future<bool> enterWhenFree({
    Duration timeout = const Duration(seconds: 10),
    Duration poll = const Duration(milliseconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!tryEnter()) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(poll);
    }
    return true;
  }

  /// Runs [body] under the latch; returns null without running it if busy.
  Future<T?> run<T>(Future<T> Function() body) async {
    if (!tryEnter()) return null;
    try {
      return await body();
    } finally {
      exit();
    }
  }
}

/// The durable end of `stopRide`, in the only safe order (§90.C8).
///
/// The recovery marker (`active_ride_id`) used to be cleared *before* the ride
/// row was finalized, with nothing guarding the gap: a kill or a throw in
/// between left the row `active` forever — invisible to history, never
/// synced, and with no marker left to restore it from. Now the row is
/// finalized first and the marker cleared last, and only once finalizing has
/// succeeded; if finalizing throws, the marker stays so the next launch's
/// `restoreInterruptedRide` can still pick the ride up, and the error
/// propagates to the caller.
///
/// [afterFinalize] (stats, invalidation, publishing) runs between the two and
/// is best-effort: its failure must not cost the rider the marker clear that
/// makes the finished ride stop looking interrupted.
Future<void> runStopSequence({
  required Future<void> Function() finalize,
  required Future<void> Function() clearMarker,
  Future<void> Function()? afterFinalize,
}) async {
  await finalize();
  try {
    if (afterFinalize != null) await afterFinalize();
  } finally {
    await clearMarker();
  }
}
