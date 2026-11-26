import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';
import 'package:throttleiq/features/simple/domain/mileage_verdict.dart';

FuelLogEntity _fill(int i, double odo, double liters, {bool full = true}) =>
    FuelLogEntity(
      id: 'f$i',
      bikeId: 'b1',
      filledAt: DateTime(2026, 11, 1 + i),
      odometerKm: odo,
      liters: liters,
      totalCost: liters * 125,
      pricePerLiter: 125,
      fullTank: full,
      createdAt: DateTime(2026, 11, 1 + i),
      updatedAt: DateTime(2026, 11, 1 + i),
    );

/// Two 100 km stretches: the first at 50 km/L, the last chosen so that
/// last ÷ average (over both) is [ratio].
List<FuelLogEntity> _withRatio(double ratio) {
  final lastLiters = 2 / (2 * ratio - 1);
  return [_fill(0, 0, 5), _fill(1, 100, 2), _fill(2, 200, lastLiters)];
}

void main() {
  test('no fills, one fill or one stretch: not enough data', () {
    for (final logs in [
      <FuelLogEntity>[],
      [_fill(0, 0, 5)],
      [_fill(0, 0, 5), _fill(1, 100, 2)],
      // A partial fill doesn't close a stretch.
      [_fill(0, 0, 5), _fill(1, 100, 2), _fill(2, 200, 2, full: false)],
    ]) {
      final r = mileageVerdict(logs);
      expect(r.verdict, MileageVerdict.notEnoughData);
      expect(r.lastKmPerLiter, isNull);
    }
  });

  test('two stretches: compares the last with the bike\'s own average', () {
    final r = mileageVerdict(_withRatio(1));
    expect(r.verdict, MileageVerdict.good);
    expect(r.lastKmPerLiter, closeTo(50, 1e-9));
    expect(r.avgKmPerLiter, closeTo(50, 1e-9));
  });

  test('good / okay / low boundaries', () {
    expect(mileageVerdict(_withRatio(1.2)).verdict, MileageVerdict.good);
    expect(mileageVerdict(_withRatio(mileageGoodRatio + 0.001)).verdict,
        MileageVerdict.good);
    expect(mileageVerdict(_withRatio(mileageGoodRatio - 0.001)).verdict,
        MileageVerdict.okay);
    expect(mileageVerdict(_withRatio(mileageOkayRatio + 0.001)).verdict,
        MileageVerdict.okay);
    expect(mileageVerdict(_withRatio(mileageOkayRatio - 0.001)).verdict,
        MileageVerdict.low);
    expect(mileageVerdict(_withRatio(0.6)).verdict, MileageVerdict.low);
  });
}
