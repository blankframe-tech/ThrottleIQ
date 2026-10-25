/// How much more (or less) fuel one ride burned than the bike's usual riding.
///
/// The rider's km/L — typed in, or measured full-to-full — is an average over
/// however they usually ride. A ride stuck in a jam burns more per km than
/// that average, a steady highway cruise less. Two effects drive it:
///
/// - **Idle**: stopped time burns fuel by the hour, not the km
///   ([idleLitresPerHour]).
/// - **Moving speed**: crawling in low gears and pushing through drag at
///   high speed both cost more per km than a steady 40–55 km/h
///   ([speedFuelFactor]).
///
/// The model is calibrated against the bike's own recent riding, so a ride
/// that looks like the usual one costs exactly the rider's km/L and only the
/// difference moves the number. Without enough history to calibrate against
/// ([kMinTelemetryKm]) the ride is costed flat.
///
/// The curve and idle rate are a heuristic, not an OEM figure, in the same
/// spirit as `riding_conditions.dart`. Pure; see `ride_fuel_test.dart`.
library;

import 'riding_conditions.dart';

/// Litres per hour an engine of [cc] burns idling; ~0.15 L/h for a 150cc
/// commuter.
double idleLitresPerHour(int? cc) =>
    ((cc != null && cc > 0) ? cc : 150) * 0.001;

/// (average moving km/h, fuel per km relative to the best) points, linearly
/// interpolated and held flat beyond the ends.
const _speedCurve = [
  (10.0, 1.6),
  (20.0, 1.3),
  (30.0, 1.12),
  (40.0, 1.0),
  (55.0, 1.0),
  (70.0, 1.1),
  (90.0, 1.3),
];

/// Fuel per km at an average moving speed of [kmh], relative to a steady
/// 40–55 km/h (1.0).
double speedFuelFactor(double kmh) {
  if (kmh <= _speedCurve.first.$1) return _speedCurve.first.$2;
  for (var i = 1; i < _speedCurve.length; i++) {
    final (x1, y1) = _speedCurve[i];
    if (kmh <= x1) {
      final (x0, y0) = _speedCurve[i - 1];
      return y0 + (y1 - y0) * (kmh - x0) / (x1 - x0);
    }
  }
  return _speedCurve.last.$2;
}

/// GPS glitches can make a ride look absurd; never move fuel further than
/// this from the flat figure.
const double kMinRideFuelFactor = 0.6;
const double kMaxRideFuelFactor = 2.0;

/// Multiplier on the flat (distance ÷ [kmPerLitre]) fuel for [ride], given
/// the bike's [usual] riding. Null when either lacks the timing to compare,
/// [usual] is too thin to calibrate from, or the numbers can't be reconciled
/// — callers then cost the ride flat.
double? rideFuelFactor({
  required UsageStats ride,
  required UsageStats usual,
  required double kmPerLitre,
  int? cc,
}) {
  if (!(kmPerLitre > 0) || usual.rideDistanceKm < kMinTelemetryKm) {
    return null;
  }
  final r = _shape(ride);
  final u = _shape(usual);
  if (r == null || u == null) return null;
  final idleRate = idleLitresPerHour(cc);
  // Usual riding burns 1/kmPerLitre per km: base·speed + idle. Solve for the
  // bike's base burn, then price this ride's mix with it.
  final base = (1 / kmPerLitre - u.idleHoursPerKm * idleRate) / u.speedFactor;
  if (!(base > 0)) return null;
  final litresPerKm = base * r.speedFactor + r.idleHoursPerKm * idleRate;
  return (litresPerKm * kmPerLitre)
      .clamp(kMinRideFuelFactor, kMaxRideFuelFactor);
}

({double speedFactor, double idleHoursPerKm})? _shape(UsageStats s) {
  if (s.rideDistanceKm <= 0 || s.movingSeconds <= 0) return null;
  final idleSeconds = (s.durationSeconds - s.movingSeconds).clamp(0, 1 << 31);
  return (
    speedFactor: speedFuelFactor(s.rideDistanceKm / (s.movingSeconds / 3600)),
    idleHoursPerKm: idleSeconds / 3600 / s.rideDistanceKm,
  );
}
