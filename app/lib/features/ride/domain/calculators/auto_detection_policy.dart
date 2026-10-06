/// Pure decisions the auto-detection pipeline makes about *when* a detection
/// may be closed or turned into a ride. Kept free of SQLite and platform
/// calls so they can be unit-tested.
library;

/// A ride's time window. [end] is null for a ride still being recorded.
typedef RideWindow = ({DateTime start, DateTime? end});

/// Whether a detection still marked `recording` should be closed (flipped to
/// `pending`) by the foreground reconciliation (§90.C2).
///
/// That close exists for detections left open by a process that died
/// mid-journey. It used to run unconditionally on every app foreground, so
/// opening the app mid-ride closed the *live* detection: the background
/// isolate then found no current recording and dropped every later fix, and
/// the ride was truncated to whatever it had so far.
///
/// Now a detection is only closed when nothing can still be appending to it —
/// the auto-tracking service isn't running — or when its last activity (last
/// fix, or its start if it has none) is older than [staleAfter], which
/// callers set comfortably past the service's own stillness timeout: a
/// detection that quiet would have been closed by the service itself if it
/// were still alive.
bool shouldCloseRecordingDetection({
  required bool serviceRunning,
  required DateTime lastActivity,
  required DateTime now,
  required Duration staleAfter,
}) {
  if (!serviceRunning) return true;
  return now.difference(lastActivity) > staleAfter;
}

/// The longest run of [fixes] that touches no existing ride (§90.C3).
///
/// Nothing stopped the background detector while the rider was recording by
/// hand, so the same journey could become two rides — a manual one and an
/// `is_auto` one — with the distance counted twice against the bike's service
/// intervals. A fix inside any ride's window is dropped, and two consecutive
/// fixes with a ride window between them are treated as a break (the manual
/// ride happened in that gap), so what is left is one contiguous stretch the
/// rider genuinely didn't record. Returns an empty list when nothing is left;
/// the reconciler's own thresholds then decide whether a non-empty remainder
/// is still a ride.
///
/// [fixes] must be in chronological order. An open-ended window (a ride
/// still recording) extends to the end of time.
List<T> longestRunClearOfRides<T>(
  List<T> fixes,
  DateTime Function(T) timeOf,
  List<RideWindow> windows,
) {
  final runs = runsClearOfRides(fixes, timeOf, windows);
  if (runs.isEmpty) return <T>[];
  var best = runs.first;
  for (final r in runs) {
    if (r.length > best.length) best = r;
  }
  return best;
}

/// Every run of [fixes] that touches no existing ride, in order — the same
/// split as [longestRunClearOfRides], without keeping only the longest.
///
/// The daily summary needs all of them: the stretch before the rider tapped
/// Start and the stretch after they tapped Stop are both real riding, and
/// each is folded into the recorded ride it touches (or counted on its own)
/// by `daily_ride_summary.dart`. Fixes inside a ride window are never part
/// of any run, so a recorded journey is never counted twice.
List<List<T>> runsClearOfRides<T>(
  List<T> fixes,
  DateTime Function(T) timeOf,
  List<RideWindow> windows,
) {
  if (fixes.isEmpty) return <List<T>>[];
  if (windows.isEmpty) return [fixes];

  bool inside(DateTime t) => windows.any((w) =>
      !t.isBefore(w.start) && (w.end == null || !t.isAfter(w.end!)));

  bool windowBetween(DateTime a, DateTime b) => windows.any((w) =>
      w.start.isBefore(b) && (w.end == null || w.end!.isAfter(a)));

  final runs = <List<T>>[];
  int? runStart;
  for (var i = 0; i < fixes.length; i++) {
    final t = timeOf(fixes[i]);
    if (inside(t)) {
      if (runStart != null) runs.add(fixes.sublist(runStart, i));
      runStart = null;
      continue;
    }
    if (runStart != null && windowBetween(timeOf(fixes[i - 1]), t)) {
      runs.add(fixes.sublist(runStart, i));
      runStart = i;
      continue;
    }
    runStart ??= i;
  }
  if (runStart != null) runs.add(fixes.sublist(runStart));
  return runs;
}
