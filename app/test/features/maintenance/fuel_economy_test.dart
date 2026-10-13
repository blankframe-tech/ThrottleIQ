import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/fuel_economy.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';

FuelLogEntity fill(
  String id,
  int day,
  double odo,
  double liters, {
  bool full = true,
  String bike = 'b1',
  double price = 130,
}) =>
    FuelLogEntity(
      id: id,
      bikeId: bike,
      filledAt: DateTime(2026, 9, day, 10),
      odometerKm: odo,
      liters: liters,
      totalCost: liters * price,
      pricePerLiter: price,
      fullTank: full,
      createdAt: DateTime(2026, 9, day, 10),
      updatedAt: DateTime(2026, 9, day, 10),
    );

void main() {
  group('fuelSegments', () {
    test('full to full: distance over the closing fill\'s litres', () {
      final s = fuelSegments([
        fill('a', 1, 1000, 8),
        fill('b', 5, 1200, 5),
      ]);
      expect(s, hasLength(1));
      expect(s.single.startLogId, 'a');
      expect(s.single.endLogId, 'b');
      expect(s.single.distanceKm, 200);
      expect(s.single.liters, 5);
      expect(s.single.kmPerLiter, 40);
      expect(s.single.costPerKm, closeTo(5 * 130 / 200, 1e-9));
    });

    test('partial fills between two full fills add their litres', () {
      final s = fuelSegments([
        fill('a', 1, 1000, 8),
        fill('p1', 3, 1100, 2, full: false),
        fill('p2', 4, 1180, 1.5, full: false),
        fill('b', 6, 1300, 4.5),
      ]);
      expect(s, hasLength(1));
      expect(s.single.liters, 8); // 2 + 1.5 + 4.5
      expect(s.single.distanceKm, 300);
      expect(s.single.kmPerLiter, 37.5);
      expect(s.single.fillCount, 3);
      expect(s.single.cost, 8 * 130);
    });

    test('the first fill is only a baseline; partials before it are ignored',
        () {
      expect(fuelSegments([fill('a', 1, 1000, 8)]), isEmpty);
      final s = fuelSegments([
        fill('p0', 1, 900, 3, full: false),
        fill('a', 2, 1000, 8),
        fill('b', 4, 1150, 5),
      ]);
      expect(s.single.startLogId, 'a');
      expect(s.single.liters, 5);
    });

    test('a partial-only history measures nothing', () {
      expect(
          fuelSegments([
            fill('p1', 1, 1000, 3, full: false),
            fill('p2', 2, 1100, 3, full: false),
          ]),
          isEmpty);
    });

    test('an odometer rollback is rejected and restarts the baseline', () {
      final s = fuelSegments([
        fill('a', 1, 1000, 8),
        fill('typo', 3, 900, 5), // runs backwards
        fill('b', 5, 1100, 5),
      ]);
      // Nothing measured across the rollback; the rolled-back full fill is
      // a fresh baseline for the next one.
      expect(s, hasLength(1));
      expect(s.single.startLogId, 'typo');
      expect(s.single.endLogId, 'b');
      expect(s.single.distanceKm, 200);
    });

    test('a partial rollback drops the pending litres', () {
      final s = fuelSegments([
        fill('a', 1, 1000, 8),
        fill('typo', 3, 800, 2, full: false),
        fill('b', 5, 1100, 5),
      ]);
      expect(s, isEmpty);
    });

    test('bikes are measured separately and merged by date', () {
      final s = fuelSegments([
        fill('a1', 1, 1000, 8),
        fill('x1', 2, 50000, 10, bike: 'b2'),
        fill('a2', 6, 1200, 5),
        fill('x2', 4, 50300, 10, bike: 'b2'),
      ]);
      expect(s.map((x) => x.endLogId), ['x2', 'a2']);
      expect(s.first.kmPerLiter, 30);
    });

    test('a second full fill at the same reading just moves the baseline', () {
      final s = fuelSegments([
        fill('a', 1, 1000, 8),
        fill('a2', 1, 1000, 0.3),
        fill('b', 4, 1100, 4),
      ]);
      expect(s.single.startLogId, 'a2');
      expect(s.single.kmPerLiter, 25);
    });
  });

  group('fillOdometerConflict', () {
    final logs = [fill('a', 1, 1000, 8), fill('b', 10, 1500, 5)];

    test('a reading between its neighbours is fine', () {
      expect(
          fillOdometerConflict(
              odometerKm: 1200, filledAt: DateTime(2026, 9, 5), others: logs),
          isNull);
    });

    test('lower than an earlier fill is rejected', () {
      expect(
          fillOdometerConflict(
              odometerKm: 900, filledAt: DateTime(2026, 9, 5), others: logs),
          FuelOdometerConflict.belowEarlierFill);
    });

    test('higher than a later fill is rejected', () {
      expect(
          fillOdometerConflict(
              odometerKm: 1600, filledAt: DateTime(2026, 9, 5), others: logs),
          FuelOdometerConflict.aboveLaterFill);
    });

    test('the fill being edited is ignored', () {
      expect(
          fillOdometerConflict(
              odometerKm: 1700,
              filledAt: DateTime(2026, 9, 10, 10),
              others: logs,
              excludeId: 'b'),
          isNull);
    });
  });

  group('completeFuelPrice', () {
    test('derives price from total, and total from price', () {
      final a = completeFuelPrice(liters: 5, totalCost: 650)!;
      expect(a.pricePerLiter, 130);
      final b = completeFuelPrice(liters: 5, pricePerLiter: 130)!;
      expect(b.totalCost, 650);
    });

    test('no usable litres or money gives null', () {
      expect(completeFuelPrice(liters: 0, totalCost: 100), isNull);
      expect(completeFuelPrice(liters: null, totalCost: 100), isNull);
      expect(completeFuelPrice(liters: 5), isNull);
    });
  });

  test('summarizeFuel weights efficiency by distance', () {
    final s = summarizeFuel([
      fill('a', 1, 1000, 8),
      fill('b', 5, 1100, 5), // 20 km/L
      fill('c', 9, 1400, 5), // 60 km/L
    ]);
    expect(s.fillCount, 3);
    expect(s.totalLiters, 18);
    expect(s.avgKmPerLiter, 40); // 400 km / 10 L, not mean(20, 60)
    expect(s.lastKmPerLiter, 60);
    expect(s.avgPricePerLiter, 130);
    expect(s.costPerKm, closeTo(1300 / 400, 1e-9));
    expect(summarizeFuel(const []).isEmpty, isTrue);
  });
}
