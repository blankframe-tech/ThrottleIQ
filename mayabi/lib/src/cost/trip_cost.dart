/// What one hired trip really costs a Mayabi: not only fuel for the paid
/// kilometres, but every kilometre she rides for it (to the pickup, the trip,
/// back home) at the full running cost of her bike.
library;

/// A wear item the rider pays for every [intervalKm]: engine oil, chain,
/// brake pads, tyres, a full service.
class MaintenanceItem {
  final String name;

  /// ৳ per replacement or service.
  final double cost;
  final double intervalKm;

  MaintenanceItem(
      {required this.name, required this.cost, required this.intervalKm}) {
    _check('cost', cost);
    if (!(intervalKm > 0) || !intervalKm.isFinite) {
      throw ArgumentError.value(intervalKm, 'intervalKm', 'must be > 0');
    }
  }

  double get costPerKm => cost / intervalKm;
}

enum CostKind { fuel, maintenance, depreciation, fixed }

/// One line of the per-km breakdown.
class CostLine {
  final CostKind kind;

  /// The maintenance item's name for [CostKind.maintenance]; null otherwise.
  final String? item;
  final double costPerKm;

  const CostLine(this.kind, this.costPerKm, [this.item]);
}

void _check(String name, double v) {
  if (!v.isFinite || v < 0) {
    throw ArgumentError.value(v, name, 'must be a finite number ≥ 0');
  }
}

/// The rider's bike and money, entered once in Maya's app and edited when
/// fuel prices move. Every value is in ৳ and km. All but fuel are optional:
/// leave them 0 and that line is left out.
class CostProfile {
  final double fuelPricePerLitre;
  final double kmPerLitre;
  final List<MaintenanceItem> maintenance;

  /// Straight-line depreciation: what the bike cost, what it will sell for,
  /// and how many km it will do in between.
  final double purchasePrice;
  final double resaleValue;
  final double lifespanKm;

  /// Monthly costs that don't depend on distance (insurance, tax token,
  /// licence, phone data, parking), spread over [monthlyKm].
  final double monthlyFixedCost;
  final double monthlyKm;

  /// Maya's share of the fare, 0–1.
  final double commissionRate;

  CostProfile({
    required this.fuelPricePerLitre,
    required this.kmPerLitre,
    this.maintenance = const [],
    this.purchasePrice = 0,
    this.resaleValue = 0,
    this.lifespanKm = 0,
    this.monthlyFixedCost = 0,
    this.monthlyKm = 0,
    this.commissionRate = 0,
  }) {
    _check('fuelPricePerLitre', fuelPricePerLitre);
    _check('purchasePrice', purchasePrice);
    _check('resaleValue', resaleValue);
    _check('lifespanKm', lifespanKm);
    _check('monthlyFixedCost', monthlyFixedCost);
    _check('monthlyKm', monthlyKm);
    if (!(kmPerLitre > 0) || !kmPerLitre.isFinite) {
      throw ArgumentError.value(kmPerLitre, 'kmPerLitre', 'must be > 0');
    }
    if (resaleValue > purchasePrice) {
      throw ArgumentError.value(
          resaleValue, 'resaleValue', 'must not exceed purchasePrice');
    }
    if (!(commissionRate >= 0 && commissionRate < 1)) {
      throw ArgumentError.value(
          commissionRate, 'commissionRate', 'must be in [0, 1)');
    }
  }

  /// Most expensive first. Depreciation needs a lifespan, fixed costs need
  /// a monthly distance; without them those lines are left out rather than
  /// guessed.
  List<CostLine> get lines {
    final out = <CostLine>[
      CostLine(CostKind.fuel, fuelPricePerLitre / kmPerLitre),
      for (final m in maintenance)
        if (m.cost > 0) CostLine(CostKind.maintenance, m.costPerKm, m.name),
      if (lifespanKm > 0 && purchasePrice > resaleValue)
        CostLine(
            CostKind.depreciation, (purchasePrice - resaleValue) / lifespanKm),
      if (monthlyKm > 0 && monthlyFixedCost > 0)
        CostLine(CostKind.fixed, monthlyFixedCost / monthlyKm),
    ];
    out.sort((a, b) => b.costPerKm.compareTo(a.costPerKm));
    return out;
  }

  double get costPerKm => lines.fold(0.0, (s, l) => s + l.costPerKm);

  /// Before accepting: the estimated km for each leg, and the offered fare.
  /// After the ride: pass the recorder's measured legs
  /// (`RideReport.pickupKm` etc.) and the fare actually paid.
  TripCost trip(
      {required double pickupKm,
      required double tripKm,
      double homeKm = 0,
      double? fare}) {
    _check('pickupKm', pickupKm);
    _check('tripKm', tripKm);
    _check('homeKm', homeKm);
    if (fare != null) _check('fare', fare);
    return TripCost._(this, pickupKm, tripKm, homeKm, fare);
  }
}

/// The cost of one trip across its three legs.
class TripCost {
  final CostProfile profile;
  final double pickupKm;
  final double tripKm;
  final double homeKm;
  final double? fare;

  TripCost._(this.profile, this.pickupKm, this.tripKm, this.homeKm, this.fare);

  double get totalKm => pickupKm + tripKm + homeKm;

  /// ৳ per cost line for this trip's total distance, most expensive first.
  List<({CostLine line, double cost})> get breakdown =>
      [for (final l in profile.lines) (line: l, cost: l.costPerKm * totalKm)];

  double get totalCost => profile.costPerKm * totalKm;
  double get pickupCost => profile.costPerKm * pickupKm;
  double get homeCost => profile.costPerKm * homeKm;

  /// Share of the km nobody pays for (to the pickup and back home), 0–1.
  double get unpaidShare => totalKm == 0 ? 0 : (pickupKm + homeKm) / totalKm;

  /// Maya's commission on the fare; null without a fare.
  double? get commission =>
      fare == null ? null : fare! * profile.commissionRate;

  /// What the rider keeps after commission and every cost; negative is a
  /// loss. Null without a fare.
  double? get netEarnings =>
      fare == null ? null : fare! - commission! - totalCost;

  /// The fare at which this trip breaks even after commission.
  double get breakEvenFare => totalCost / (1 - profile.commissionRate);

  Map<String, Object?> toJson() => {
        'pickupKm': pickupKm,
        'tripKm': tripKm,
        'homeKm': homeKm,
        'fare': fare,
        'costPerKm': profile.costPerKm,
        'totalCost': totalCost,
        'unpaidShare': unpaidShare,
        'commission': commission,
        'netEarnings': netEarnings,
        'breakEvenFare': breakEvenFare,
        'breakdown': [
          for (final b in breakdown)
            {'kind': b.line.kind.name, 'item': b.line.item, 'cost': b.cost},
        ],
      };
}
