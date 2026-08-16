/// How much to trust which bike a ride is attributed to.
///
/// This exists because ThrottleIQ's maintenance model is distance-based:
/// service intervals, chain lube and `computeNextService` all read from
/// per-bike accumulated distance. A ride credited to the wrong bike does not
/// merely mislabel a row in history — it moves two bikes' service schedules at
/// once, in opposite directions, and the rider has no reason to suspect it.
///
/// A manually started ride is unambiguous: the rider picked the bike on the
/// record screen moments before sliding to start. An auto-started ride has no
/// such signal, so it must record that it guessed, and the guess must be
/// visible and correctable rather than silently folded into the maintenance
/// math.
enum BikeAttributionConfidence {
  /// The rider chose this bike for this ride, or it is the only bike in the
  /// garage. Safe to count toward maintenance immediately.
  high,

  /// Inferred — auto-tracking fell back to whichever bike happened to be
  /// active. Counts toward distance totals (the ride did happen, and on
  /// *something*), but is surfaced for confirmation and can be reattributed.
  low,

  /// Was [low], and the rider has since confirmed or corrected it. Behaves
  /// like [high] from here on; kept distinct so the confirmation prompt knows
  /// not to ask twice, and so detection accuracy can be measured after the
  /// fact.
  confirmed;

  /// Whether this ride still needs the rider to say which bike it was.
  bool get needsConfirmation => this == BikeAttributionConfidence.low;

  static BikeAttributionConfidence fromName(String? name) =>
      BikeAttributionConfidence.values.firstWhere(
        (e) => e.name == name,
        orElse: () => BikeAttributionConfidence.high,
      );
}
