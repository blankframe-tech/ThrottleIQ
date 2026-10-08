/// Elapsed ride time at the instant of a pause (issues §101.R10).
///
/// The recorder used to freeze `state.elapsed`, the last 1 Hz tick, so every
/// pause dropped up to a second. This takes the real active time instead:
/// [accumulated] (earlier segments) plus now minus [activeStart]. It never
/// returns less than [lastTick], what the rider already saw, even if the
/// wall clock stepped backwards. With no [activeStart] (restored ride) the
/// last tick is all there is.
Duration elapsedAtPause({
  required Duration accumulated,
  required DateTime? activeStart,
  required DateTime now,
  required Duration lastTick,
}) {
  if (activeStart == null) return lastTick;
  final live = accumulated + now.difference(activeStart);
  return live > lastTick ? live : lastTick;
}
