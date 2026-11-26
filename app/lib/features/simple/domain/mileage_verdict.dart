/// Simple Home's mileage line: the last measured km/L, judged against the
/// bike's own average. Pure, unit-tested in
/// `test/features/simple/mileage_verdict_test.dart`.
library;

import '../../maintenance/domain/calculators/fuel_economy.dart';
import '../../maintenance/domain/entities/fuel_log.dart';

enum MileageVerdict {
  notEnoughData,

  /// One measured stretch: a km/L to show, nothing yet to judge it against.
  firstOnly,
  good,
  okay,
  low,
}

/// Last stretch at or above this share of the average: good.
const mileageGoodRatio = 0.95;

/// Last stretch at or above this share (and below good): okay. Below: low.
const mileageOkayRatio = 0.85;

typedef MileageReading = ({
  MileageVerdict verdict,
  double? lastKmPerLiter,
  double? avgKmPerLiter,
});

/// No measured full-to-full stretch: nothing to show (two full fills make
/// one, as in the full app's fuel card). One stretch: its km/L, unjudged,
/// since there is no "usual" yet (no per-model defaults).
MileageReading mileageVerdict(Iterable<FuelLogEntity> logs) {
  final list = logs.toList();
  final stretches = fuelSegments(list).length;
  if (stretches == 0) {
    return (
      verdict: MileageVerdict.notEnoughData,
      lastKmPerLiter: null,
      avgKmPerLiter: null,
    );
  }
  final s = summarizeFuel(list);
  final last = s.lastKmPerLiter!;
  final avg = s.avgKmPerLiter!;
  if (stretches == 1) {
    return (
      verdict: MileageVerdict.firstOnly,
      lastKmPerLiter: last,
      avgKmPerLiter: avg,
    );
  }
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
