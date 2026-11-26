/// Simple Home's mileage line: the last measured km/L, judged against the
/// bike's own average. Pure, unit-tested in
/// `test/features/simple/mileage_verdict_test.dart`.
library;

import '../../maintenance/domain/calculators/fuel_economy.dart';
import '../../maintenance/domain/entities/fuel_log.dart';

enum MileageVerdict { notEnoughData, good, okay, low }

/// Last stretch at or above this share of the average: good.
const mileageGoodRatio = 0.95;

/// Last stretch at or above this share (and below good): okay. Below: low.
const mileageOkayRatio = 0.85;

typedef MileageReading = ({
  MileageVerdict verdict,
  double? lastKmPerLiter,
  double? avgKmPerLiter,
});

/// With fewer than two measured full-to-full stretches there is no "usual"
/// to compare with, so it says so instead of guessing (no per-model defaults).
MileageReading mileageVerdict(Iterable<FuelLogEntity> logs) {
  final list = logs.toList();
  if (fuelSegments(list).length < 2) {
    return (
      verdict: MileageVerdict.notEnoughData,
      lastKmPerLiter: null,
      avgKmPerLiter: null,
    );
  }
  final s = summarizeFuel(list);
  final last = s.lastKmPerLiter!;
  final avg = s.avgKmPerLiter!;
  final ratio = last / avg;
  return (
    verdict: ratio >= mileageGoodRatio
        ? MileageVerdict.good
        : ratio >= mileageOkayRatio
            ? MileageVerdict.okay
            : MileageVerdict.low,
    lastKmPerLiter: last,
    avgKmPerLiter: avg,
  );
}
