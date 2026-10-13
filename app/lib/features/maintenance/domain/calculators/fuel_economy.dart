/// Fuel efficiency and spend from logged fill-ups. Pure: no clock, SQLite or
/// Flutter, so every rule here is unit-tested directly
/// (`test/features/maintenance/fuel_economy_test.dart`).
///
/// Efficiency uses the standard full-to-full method. A full tank is a known
/// level, so between two full fills the fuel burned is exactly what was put
/// back in: the closing fill's litres plus any partial fills in between. A
/// partial fill on its own says nothing about consumption, and the first
/// full fill only sets the baseline.
library;

import '../entities/fuel_log.dart';

/// One measured stretch between two full-tank fill-ups of the same bike.
class FuelSegment {
  final String bikeId;

  /// The full fill that opened the stretch (the baseline).
  final String startLogId;

  /// The full fill that closed it. Its date is the segment's date.
  final String endLogId;
  final DateTime start;
  final DateTime end;
  final double distanceKm;

  /// Litres burned: the closing fill plus partial fills in between.
  final double liters;

  /// What those litres cost.
  final double cost;

  /// How many fills the stretch's litres came from (1 = no partials).
  final int fillCount;

  const FuelSegment({
    required this.bikeId,
    required this.startLogId,
    required this.endLogId,
    required this.start,
    required this.end,
    required this.distanceKm,
    required this.liters,
    required this.cost,
    required this.fillCount,
  });

  double get kmPerLiter => distanceKm / liters;
  double get costPerKm => cost / distanceKm;

  @override
  String toString() => 'FuelSegment($startLogId→$endLogId, '
      '${distanceKm}km, ${liters}L, ${kmPerLiter.toStringAsFixed(2)} km/L)';
}

/// Chronological order for one bike's fills: by date, then odometer (two
/// fills logged for the same moment are ordered by the reading), then id
/// so the order is total.
int compareFills(FuelLogEntity a, FuelLogEntity b) {
  final t = a.filledAt.compareTo(b.filledAt);
  if (t != 0) return t;
  final o = a.odometerKm.compareTo(b.odometerKm);
  if (o != 0) return o;
  return a.id.compareTo(b.id);
}

/// Every measurable full-to-full stretch in [logs], oldest first. Bikes are
/// measured separately and merged by end date.
///
/// A fill whose odometer is lower than the fill before it (a rollback — a
/// typo, or a reading from another bike) breaks the chain: nothing is
/// measured across it, and the next full fill starts a fresh baseline. The
/// form refuses to save such a fill ([fillOdometerConflict]); this guards
/// data that arrived some other way (sync, older builds).
List<FuelSegment> fuelSegments(Iterable<FuelLogEntity> logs) {
  final byBike = <String, List<FuelLogEntity>>{};
  for (final l in logs) {
    (byBike[l.bikeId] ??= []).add(l);
  }
  final out = <FuelSegment>[];
  for (final fills in byBike.values) {
    fills.sort(compareFills);
    FuelLogEntity? baseline;
    FuelLogEntity? prev;
    var pendingLiters = 0.0;
    var pendingCost = 0.0;
    var pendingFills = 0;
    for (final f in fills) {
      if (prev != null && f.odometerKm < prev.odometerKm) {
        baseline = f.fullTank ? f : null;
        pendingLiters = 0;
        pendingCost = 0;
        pendingFills = 0;
        prev = f;
        continue;
      }
      pendingLiters += f.liters;
      pendingCost += f.totalCost;
      pendingFills++;
      if (f.fullTank) {
        final base = baseline;
        if (base != null &&
            f.odometerKm > base.odometerKm &&
            pendingLiters > 0) {
          out.add(FuelSegment(
            bikeId: f.bikeId,
            startLogId: base.id,
            endLogId: f.id,
            start: base.filledAt,
            end: f.filledAt,
            distanceKm: f.odometerKm - base.odometerKm,
            liters: pendingLiters,
            cost: pendingCost,
            fillCount: pendingFills,
          ));
        }
        // A full fill at the same reading as the baseline (topping off
        // twice) just moves the baseline: the tank is full either way.
        baseline = f;
        pendingLiters = 0;
        pendingCost = 0;
        pendingFills = 0;
      }
      prev = f;
    }
  }
  out.sort((a, b) {
    final c = a.end.compareTo(b.end);
    return c != 0 ? c : a.endLogId.compareTo(b.endLogId);
  });
  return out;
}

/// km/L for each closing fill id, for labelling the list.
Map<String, double> kmPerLiterByFill(Iterable<FuelLogEntity> logs) => {
      for (final s in fuelSegments(logs)) s.endLogId: s.kmPerLiter,
    };

/// Why a fill's odometer can't be right, given the bike's other fills.
enum FuelOdometerConflict {
  /// Lower than a fill logged earlier — the odometer would run backwards.
  belowEarlierFill,

  /// Higher than a fill logged later.
  aboveLaterFill,
}

/// Checks [odometerKm] at [filledAt] against [others] (the same bike's other
/// fills; the one being edited, [excludeId], is ignored). Null when it fits.
///
/// Fills at the very same moment are ordered by their readings
/// ([compareFills]), so they never conflict with each other.
FuelOdometerConflict? fillOdometerConflict({
  required double odometerKm,
  required DateTime filledAt,
  required Iterable<FuelLogEntity> others,
  String? excludeId,
}) {
  for (final o in others) {
    if (o.id == excludeId) continue;
    if (o.filledAt.isBefore(filledAt) && o.odometerKm > odometerKm) {
      return FuelOdometerConflict.belowEarlierFill;
    }
  }
  for (final o in others) {
    if (o.id == excludeId) continue;
    if (o.filledAt.isAfter(filledAt) && o.odometerKm < odometerKm) {
      return FuelOdometerConflict.aboveLaterFill;
    }
  }
  return null;
}

/// The other of total cost and price per litre, from whichever the rider
/// typed. Returns null when [liters] is unusable or neither is given.
({double totalCost, double pricePerLiter})? completeFuelPrice({
  required double? liters,
  double? totalCost,
  double? pricePerLiter,
}) {
  if (liters == null || !liters.isFinite || liters <= 0) return null;
  if (totalCost != null && totalCost.isFinite && totalCost >= 0) {
    return (totalCost: totalCost, pricePerLiter: totalCost / liters);
  }
  if (pricePerLiter != null && pricePerLiter.isFinite && pricePerLiter >= 0) {
    return (totalCost: pricePerLiter * liters, pricePerLiter: pricePerLiter);
  }
  return null;
}

/// Headline numbers for a set of fills.
class FuelSummary {
  final int fillCount;
  final double totalCost;
  final double totalLiters;

  /// Total distance over total litres across every measured stretch — not a
  /// mean of per-stretch figures, which would over-weight short ones.
  final double? avgKmPerLiter;

  /// The most recent measured stretch.
  final double? lastKmPerLiter;

  /// ৳ per km across measured stretches.
  final double? costPerKm;

  /// Average ৳ per litre paid.
  final double? avgPricePerLiter;

  const FuelSummary({
    required this.fillCount,
    required this.totalCost,
    required this.totalLiters,
    this.avgKmPerLiter,
    this.lastKmPerLiter,
    this.costPerKm,
    this.avgPricePerLiter,
  });

  static const empty = FuelSummary(fillCount: 0, totalCost: 0, totalLiters: 0);

  bool get isEmpty => fillCount == 0;
}

FuelSummary summarizeFuel(Iterable<FuelLogEntity> logs) {
  final list = logs.toList();
  if (list.isEmpty) return FuelSummary.empty;
  final totalCost = list.fold<double>(0, (s, l) => s + l.totalCost);
  final totalLiters = list.fold<double>(0, (s, l) => s + l.liters);
  final segments = fuelSegments(list);
  final segKm = segments.fold<double>(0, (s, x) => s + x.distanceKm);
  final segL = segments.fold<double>(0, (s, x) => s + x.liters);
  final segCost = segments.fold<double>(0, (s, x) => s + x.cost);
  return FuelSummary(
    fillCount: list.length,
    totalCost: totalCost,
    totalLiters: totalLiters,
    avgKmPerLiter: segL > 0 ? segKm / segL : null,
    lastKmPerLiter: segments.isEmpty ? null : segments.last.kmPerLiter,
    costPerKm: segKm > 0 ? segCost / segKm : null,
    avgPricePerLiter: totalLiters > 0 ? totalCost / totalLiters : null,
  );
}
