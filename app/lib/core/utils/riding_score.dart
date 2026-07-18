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
