/// Single source of truth for the 0-100 riding score, shared by the
/// per-ride summary card and the all-time rider stats hub.
int computeRidingScore({
  required int hardBrakes,
  required int rapidAccel,
  required int highJerk,
}) {
  final deductions = (hardBrakes * 5) + (rapidAccel * 3) + (highJerk * 1);
  return (100 - deductions).clamp(0, 100);
}

/// The three riding-score bands a score maps to. Named `smooth`/`steady`/
/// `aggressive` to match the existing `scoreSmoothLabel`/`scoreSteadyLabel`/
/// `scoreAggressiveLabel` l10n keys — this is the pure half of that mapping,
/// kept Flutter-free so it can be shared by both the private ride summary
/// screen and the shared-ride feed/detail cards without either owning the
/// thresholds independently (see DOCS/Handoff for agents and Todos/issues_open.md or issues_fixed.md §62.8 for what happens when
/// a plausibility rule gets reimplemented in more than one place).
enum RidingScoreTier { smooth, steady, aggressive }

RidingScoreTier ridingScoreTier(int score) {
  if (score >= 80) return RidingScoreTier.smooth;
  if (score >= 60) return RidingScoreTier.steady;
  return RidingScoreTier.aggressive;
}
