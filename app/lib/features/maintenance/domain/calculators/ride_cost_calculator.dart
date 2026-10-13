import '../entities/maintenance_entity.dart';

/// Where an item's per-service price came from.
enum CostSource {
  /// Average of the costs the rider actually logged for this item.
  history,

  /// The rider's own "typical cost" estimate on the check.
  typical,

  /// Fuel price & mileage from the bike's running-cost settings.
  fuel,
}

/// One priced line of a running-cost breakdown.
class RideCostLine {
  final ServiceType serviceType;

  /// ৳ per km for this item.
  final double costPerKm;

  /// ৳ for the distance the breakdown was computed for.
  final double cost;
  final CostSource source;

  const RideCostLine({
    required this.serviceType,
    required this.costPerKm,
    required this.cost,
    required this.source,
  });
}

class RideCostBreakdown {
  final double distanceKm;

  /// Most expensive first; only items that had usable cost data.
  final List<RideCostLine> lines;

  const RideCostBreakdown({required this.distanceKm, required this.lines});

  bool get isEmpty => lines.isEmpty;
  double get total => lines.fold(0.0, (s, l) => s + l.cost);
  double get costPerKm => lines.fold(0.0, (s, l) => s + l.costPerKm);
}

/// Pure running-cost maths — no providers, no database.
///
/// cost/km for fuel   = price per litre / km per litre
/// cost/km for a check = per-service price / service interval (km), where the
///   per-service price is the mean of the rider's logged costs for that item
///   (actual history wins), falling back to the check's typical cost.
/// ride cost          = distance × Σ cost/km, per line.
///
/// Only enabled checks count ("things I maintain"); the `fuel` check is
/// priced from [BikeRunningCostEntity] instead of its interval, since a
/// refill interval says nothing about litres burned.
class RideCostCalculator {
  const RideCostCalculator._();

  static double? fuelCostPerKm({double? pricePerLitre, double? kmPerLitre}) {
    if (pricePerLitre == null || kmPerLitre == null) return null;
    if (pricePerLitre <= 0 || kmPerLitre <= 0) return null;
    return pricePerLitre / kmPerLitre;
  }

  /// Mean of the positive logged costs, or null when none carry a cost.
  static double? averageLoggedCost(Iterable<MaintenanceEntity> logs) {
    final costs =
        logs.map((l) => l.cost).whereType<double>().where((c) => c > 0);
    if (costs.isEmpty) return null;
    return costs.reduce((a, b) => a + b) / costs.length;
  }

  static ({double costPerKm, CostSource source})? itemCostPerKm({
    required double intervalKm,
    double? typicalCost,
    Iterable<MaintenanceEntity> logs = const [],
  }) {
    if (intervalKm <= 0) return null;
    final avg = averageLoggedCost(logs);
    if (avg != null) {
      return (costPerKm: avg / intervalKm, source: CostSource.history);
    }
    if (typicalCost != null && typicalCost > 0) {
      return (costPerKm: typicalCost / intervalKm, source: CostSource.typical);
    }
    return null;
  }

  static RideCostBreakdown compute({
    required double distanceKm,
    required List<MaintenanceConfigEntity> configs,
    required List<MaintenanceEntity> logs,
    BikeRunningCostEntity? runningCost,
  }) {
    final distance = distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0.0;
    final lines = <RideCostLine>[];

    final fuel = fuelCostPerKm(
      pricePerLitre: runningCost?.fuelPricePerLitre,
      kmPerLitre: runningCost?.kmPerLitre,
    );
    if (fuel != null) {
      lines.add(RideCostLine(
        serviceType: ServiceType.fuel,
        costPerKm: fuel,
        cost: fuel * distance,
        source: CostSource.fuel,
      ));
    }

    for (final config in configs) {
      if (!config.isEnabled) continue;
      if (config.serviceType == ServiceType.fuel ||
          config.serviceType == ServiceType.custom) {
        continue;
      }
      final priced = itemCostPerKm(
        intervalKm: config.intervalKm,
        typicalCost: config.typicalCost,
        logs: logs.where((l) => l.serviceType == config.serviceType),
      );
      if (priced == null) continue;
      lines.add(RideCostLine(
        serviceType: config.serviceType,
        costPerKm: priced.costPerKm,
        cost: priced.costPerKm * distance,
        source: priced.source,
      ));
    }

    lines.sort((a, b) => b.costPerKm.compareTo(a.costPerKm));
    return RideCostBreakdown(distanceKm: distance, lines: lines);
  }
}
