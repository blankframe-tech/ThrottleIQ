/// Turns how a bike is actually ridden into shorter service intervals.
///
/// Owner's manuals already say this in prose — "service more often in dusty
/// conditions, heavy stop-and-go traffic" — and Yamaha Y-Connect's Auto mode
/// applies it. Here it comes from telemetry the app already records, and
/// every adjustment carries an [AdaptReason] so the rider sees *why* an
/// interval shrank ("Stop-and-go 38%") instead of a number that just moved.
///
/// The factors are a heuristic, not an OEM figure (issues §95): they start
/// conservative (never below [kMinConditionFactor]) and the rider can switch
/// adaptation off in maintenance settings.
///
/// Pure: inputs are aggregates, so this is tested without a database.
library;

import '../entities/maintenance_entity.dart';

/// The rider's own description of their roads, chosen in setup. Telemetry
/// can measure traffic, not dust or flooded roads.
enum RidingProfile { normal, severe }

extension RidingProfileExt on RidingProfile {
  static RidingProfile fromString(String? s) =>
      RidingProfile.values.where((p) => p.name == s).firstOrNull ??
      RidingProfile.normal;
}

enum AdaptReasonKind { stopAndGo, hardBraking, severeRoads }

class AdaptReason {
  final AdaptReasonKind kind;

  /// Multiplier on the interval (0.8 = 20% shorter).
  final double factor;

  /// The measurement behind it: idle share 0–1 for [AdaptReasonKind.stopAndGo],
  /// hard brakes per 100 km for [AdaptReasonKind.hardBraking]; null for the
  /// rider-chosen [AdaptReasonKind.severeRoads].
  final double? measure;

  const AdaptReason(this.kind, this.factor, [this.measure]);

  /// Whole-percent shortening, for "−20%" chips.
  int get percentShorter => ((1 - factor) * 100).round();
}

/// Aggregates of a bike's recent riding, from completed rides (and detected
/// trips for distance).
class UsageStats {
  /// Distance per day over the recent window, rides and detected trips
  /// together. Null when there's too little riding to project from.
  final double? avgDailyKm;

  /// Recorded rides in the telemetry window.
  final double rideDistanceKm;
  final int movingSeconds;
  final int durationSeconds;
  final int hardBrakes;

  const UsageStats({
    this.avgDailyKm,
    this.rideDistanceKm = 0,
    this.movingSeconds = 0,
    this.durationSeconds = 0,
    this.hardBrakes = 0,
  });

  static const empty = UsageStats();

  /// Share of ride time spent stopped or crawling, 0–1.
  double? get idleShare => durationSeconds > 0
      ? (1 - movingSeconds / durationSeconds).clamp(0.0, 1.0)
      : null;

  double? get hardBrakesPer100Km =>
      rideDistanceKm > 0 ? hardBrakes / rideDistanceKm * 100 : null;
}

/// Telemetry only counts once there's enough of it to mean something.
const double kMinTelemetryKm = 100;

/// No combination of conditions shortens an interval by more than 30%.
const double kMinConditionFactor = 0.7;

class ConditionProfile {
  final Map<ServiceType, List<AdaptReason>> reasons;
  const ConditionProfile(this.reasons);

  static const none = ConditionProfile({});

  List<AdaptReason> reasonsFor(ServiceType type) => reasons[type] ?? const [];

  double factorFor(ServiceType type) {
    var f = 1.0;
    for (final r in reasonsFor(type)) {
      f *= r.factor;
    }
    return f < kMinConditionFactor ? kMinConditionFactor : f;
  }

  bool get isEmpty => reasons.values.every((r) => r.isEmpty);
}

/// Items shortened by heavy stop-and-go traffic: the engine idles hot with
/// little airflow and the clutch is worked constantly.
const _stopAndGoTypes = [
  ServiceType.oilChange,
  ServiceType.oilFilter,
  ServiceType.clutchCable,
];

const _brakeTypes = [
  ServiceType.frontDiscPads,
  ServiceType.rearDrumPads,
  ServiceType.brakeRotors,
];

/// Dust and water: the air filter clogs, the chain loses its lube.
const _severeRoadFactors = {
  ServiceType.airFilter: 0.7,
  ServiceType.chain: 0.7,
  ServiceType.chainTension: 0.8,
};

ConditionProfile deriveConditions({
  required UsageStats usage,
  required RidingProfile profile,
}) {
  final reasons = <ServiceType, List<AdaptReason>>{};
  void add(ServiceType t, AdaptReason r) => (reasons[t] ??= []).add(r);

  final enoughTelemetry = usage.rideDistanceKm >= kMinTelemetryKm;

  final idle = usage.idleShare;
  if (enoughTelemetry && idle != null) {
    final factor = idle >= 0.35 ? 0.8 : (idle >= 0.2 ? 0.9 : 1.0);
    if (factor < 1) {
      for (final t in _stopAndGoTypes) {
        add(t, AdaptReason(AdaptReasonKind.stopAndGo, factor, idle));
      }
    }
  }

  final brakes = usage.hardBrakesPer100Km;
  if (enoughTelemetry && brakes != null && brakes >= 3) {
    for (final t in _brakeTypes) {
      add(t, AdaptReason(AdaptReasonKind.hardBraking, 0.85, brakes));
    }
  }

  if (profile == RidingProfile.severe) {
    _severeRoadFactors.forEach((t, f) {
      add(t, AdaptReason(AdaptReasonKind.severeRoads, f));
    });
  }

  return ConditionProfile(reasons);
}
