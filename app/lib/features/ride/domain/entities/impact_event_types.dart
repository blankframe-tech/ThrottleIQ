/// Shared vocabulary for shadow-mode crash detection: where the phone rode,
/// and what the rider said an impact was. The `wire` strings are what SQLite,
/// Firestore and `firestore.rules` store; never rename one.
library;

/// Where the phone sat during a ride. Changes what a crash looks like to the
/// sensors (crash-detection plan §6), so every ride and impact records it.
enum PhonePlacement {
  mount('mount'),
  pocket('pocket'),
  bag('bag'),
  unknown('unknown');

  const PhonePlacement(this.wire);
  final String wire;

  static PhonePlacement fromWire(String? s) => PhonePlacement.values
      .firstWhere((p) => p.wire == s, orElse: () => PhonePlacement.unknown);
}

/// The rider's answer to "Did you fall?" — or a fall they reported that the
/// detector missed ([missed]).
enum ImpactLabel {
  crash('crash'),
  fall('fall'),
  phoneFell('phone_fell'),
  bump('bump'),
  hardStop('hard_stop'),
  unsure('unsure'),
  missed('missed');

  const ImpactLabel(this.wire);
  final String wire;

  /// A real crash or fall, as opposed to a false alarm or a shrug.
  bool get isFall =>
      this == ImpactLabel.crash ||
      this == ImpactLabel.fall ||
      this == ImpactLabel.missed;

  static ImpactLabel? fromWire(String? s) {
    for (final l in ImpactLabel.values) {
      if (l.wire == s) return l;
    }
    return null;
  }
}

enum ImpactSeverity {
  none('none'),
  minor('minor'),
  medical('medical');

  const ImpactSeverity(this.wire);
  final String wire;
}

enum RoadSurface {
  paved('paved'),
  broken('broken'),
  dirt('dirt'),
  gravel('gravel'),
  wet('wet'),
  railCrossing('rail_crossing'),
  speedBump('speed_bump');

  const RoadSurface(this.wire);
  final String wire;
}
