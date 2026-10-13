/// What a bike costs to keep running: spend per month, per km, and where it
/// goes. Pure, like the other calculators here.
library;

import '../entities/maintenance_entity.dart';
import '../entities/service_visit.dart';

/// Where a ৳ went. Visits billed as one total can't be split by item, so
/// they land in [visit] rather than being guessed apart.
enum SpendBucket { oil, parts, visit }

class MonthSpend {
  final int year;
  final int month;
  final double amount;
  const MonthSpend(this.year, this.month, this.amount);
}

class MaintenanceMoney {
  /// Last [months] calendar months, oldest first, current month included.
  final List<MonthSpend> monthly;

  /// Spend over the last 365 days.
  final double spend12m;

  /// [spend12m] ÷ km ridden in the same window; null without distance.
  final double? maintenancePerKm;

  /// Fuel ৳/km from the bike's running-cost settings; null if unset.
  final double? fuelPerKm;
  final Map<SpendBucket, double> split;

  const MaintenanceMoney({
    required this.monthly,
    required this.spend12m,
    this.maintenancePerKm,
    this.fuelPerKm,
    required this.split,
  });

  double? get totalPerKm => (maintenancePerKm == null && fuelPerKm == null)
      ? null
      : (maintenancePerKm ?? 0) + (fuelPerKm ?? 0);

  bool get isEmpty => spend12m <= 0 && fuelPerKm == null;
}

const _oilTypes = {ServiceType.oilChange, ServiceType.oilFilter};

MaintenanceMoney computeMoney({
  required List<MaintenanceEntity> logs,
  required DateTime now,
  double? distanceKm12m,
  double? fuelPricePerLitre,
  double? kmPerLitre,
  int months = 6,
}) {
  final visits = groupVisits(logs);
  final yearAgo = now.subtract(const Duration(days: 365));

  final monthly = <MonthSpend>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i);
    final amount = visits
        .where((v) => v.date.year == m.year && v.date.month == m.month)
        .map((v) => v.totalCost ?? 0)
        .fold<double>(0, (a, b) => a + b);
    monthly.add(MonthSpend(m.year, m.month, amount));
  }

  var spend12m = 0.0;
  final split = {for (final b in SpendBucket.values) b: 0.0};
  for (final v in visits.where((v) => v.date.isAfter(yearAgo))) {
    final total = v.totalCost ?? 0;
    spend12m += total;
    final itemized = v.items.every((i) => i.visitTotal == null);
    if (!itemized && v.items.length > 1) {
      split[SpendBucket.visit] = split[SpendBucket.visit]! + total;
      continue;
    }
    for (final i in v.items) {
      final c = i.cost ?? (v.items.length == 1 ? total : 0);
      final bucket =
          _oilTypes.contains(i.serviceType) ? SpendBucket.oil : SpendBucket.parts;
      split[bucket] = split[bucket]! + c;
    }
  }

  final fuelPerKm = (fuelPricePerLitre != null &&
          kmPerLitre != null &&
          fuelPricePerLitre > 0 &&
          kmPerLitre > 0)
      ? fuelPricePerLitre / kmPerLitre
      : null;

  return MaintenanceMoney(
    monthly: monthly,
    spend12m: spend12m,
    maintenancePerKm: (distanceKm12m != null && distanceKm12m >= 50 && spend12m > 0)
        ? spend12m / distanceKm12m
        : null,
    fuelPerKm: fuelPerKm,
    split: split,
  );
}
