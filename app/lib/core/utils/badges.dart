import 'rider_stats.dart';

/// A milestone badge — earned/not-earned is always a pure function of the
/// rider's local ride/bike history (mirrors [RiderStatsSummary] itself), so
/// the UI never waits on a network round trip to know what's earned.
class BadgeDef {
  final String id;
  final String name;
  final bool Function(RiderStatsSummary stats) isEarned;

  const BadgeDef({required this.id, required this.name, required this.isEarned});
}

class EarnedBadge {
  final BadgeDef def;
  final bool earned;
  const EarnedBadge(this.def, this.earned);
}

const List<BadgeDef> badgeDefs = [
  BadgeDef(id: 'first_ride', name: 'First ride', isEarned: _rides1),
  BadgeDef(id: 'km_100', name: '100 km', isEarned: _km100),
  BadgeDef(id: 'km_500', name: '500 km', isEarned: _km500),
  BadgeDef(id: 'km_1000', name: '1,000 km', isEarned: _km1000),
  BadgeDef(id: 'km_2500', name: '2,500 km', isEarned: _km2500),
  BadgeDef(id: 'km_5000', name: '5,000 km', isEarned: _km5000),
  BadgeDef(id: 'rides_10', name: '10 rides', isEarned: _rides10),
  BadgeDef(id: 'rides_25', name: '25 rides', isEarned: _rides25),
  BadgeDef(id: 'rides_50', name: '50 rides', isEarned: _rides50),
  BadgeDef(id: 'rides_100', name: '100 rides', isEarned: _rides100),
  BadgeDef(id: 'ton_up', name: 'Ton-up', isEarned: _tonUp),
  BadgeDef(id: 'speed_demon', name: 'Speed demon', isEarned: _speedDemon),
  BadgeDef(id: 'smooth_operator', name: 'Smooth operator', isEarned: _smoothOperator),
];

List<EarnedBadge> computeBadges(RiderStatsSummary stats) =>
    [for (final def in badgeDefs) EarnedBadge(def, def.isEarned(stats))];

bool _rides1(RiderStatsSummary s) => s.totalRides >= 1;
bool _rides10(RiderStatsSummary s) => s.totalRides >= 10;
bool _rides25(RiderStatsSummary s) => s.totalRides >= 25;
bool _rides50(RiderStatsSummary s) => s.totalRides >= 50;
bool _rides100(RiderStatsSummary s) => s.totalRides >= 100;
bool _km100(RiderStatsSummary s) => s.totalDistanceKm >= 100;
bool _km500(RiderStatsSummary s) => s.totalDistanceKm >= 500;
bool _km1000(RiderStatsSummary s) => s.totalDistanceKm >= 1000;
bool _km2500(RiderStatsSummary s) => s.totalDistanceKm >= 2500;
bool _km5000(RiderStatsSummary s) => s.totalDistanceKm >= 5000;
bool _tonUp(RiderStatsSummary s) => s.allTimeTopSpeedKmh >= 100;
bool _speedDemon(RiderStatsSummary s) => s.allTimeTopSpeedKmh >= 160;
bool _smoothOperator(RiderStatsSummary s) =>
    s.totalRides >= 5 && s.avgRidingScore >= 90;
