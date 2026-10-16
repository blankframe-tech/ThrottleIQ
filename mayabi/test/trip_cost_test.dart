import 'package:test/test.dart';
import 'package:throttleiq_mayabi/throttleiq_mayabi.dart';

CostProfile scooter({double commission = 0.2}) => CostProfile(
      fuelPricePerLitre: 165, // octane, 21 Sep 2026
      kmPerLitre: 45,
      maintenance: [
        MaintenanceItem(name: 'Engine oil', cost: 900, intervalKm: 2000),
        MaintenanceItem(name: 'Tyres', cost: 6000, intervalKm: 20000),
      ],
      purchasePrice: 180000,
      resaleValue: 80000,
      lifespanKm: 60000,
      monthlyFixedCost: 1500,
      monthlyKm: 1500,
      commissionRate: commission,
    );

void main() {
  test(
      'per-km lines: fuel, each maintenance item, depreciation, fixed; most expensive first',
      () {
    final lines = scooter().lines;
    expect(lines.map((l) => l.kind), [
      CostKind.fuel,
      CostKind.depreciation,
      CostKind.fixed,
      CostKind.maintenance,
      CostKind.maintenance
    ]);
    expect(lines.first.costPerKm, closeTo(165 / 45, 1e-9));
    expect(lines[1].costPerKm, closeTo(100000 / 60000, 1e-9));
    expect(lines[2].costPerKm, 1.0);
    expect(lines[3].item, 'Engine oil');
    expect(
        scooter().costPerKm, closeTo(3.6667 + 1.6667 + 1 + 0.45 + 0.3, 1e-3));
  });

  test('a trip counts the unpaid pickup and ride home', () {
    final t = scooter().trip(pickupKm: 3, tripKm: 8, homeKm: 6, fare: 150);
    final perKm = scooter().costPerKm;
    expect(t.totalKm, 17);
    expect(t.totalCost, closeTo(17 * perKm, 1e-9));
    expect(t.pickupCost, closeTo(3 * perKm, 1e-9));
    expect(t.homeCost, closeTo(6 * perKm, 1e-9));
    expect(t.unpaidShare, closeTo(9 / 17, 1e-9));
    expect(t.commission, 30);
    expect(t.netEarnings, closeTo(150 - 30 - 17 * perKm, 1e-9));
    expect(t.breakEvenFare, closeTo(17 * perKm / 0.8, 1e-9));
    expect(t.breakdown.fold(0.0, (s, b) => s + b.cost),
        closeTo(t.totalCost, 1e-9));
  });

  test('a low fare is a loss; no fare means no earnings figures', () {
    expect(
        scooter()
            .trip(pickupKm: 5, tripKm: 4, homeKm: 5, fare: 60)
            .netEarnings!,
        lessThan(0));
    final t = scooter().trip(pickupKm: 1, tripKm: 2);
    expect(t.netEarnings, isNull);
    expect(t.commission, isNull);
    expect(t.unpaidShare, closeTo(1 / 3, 1e-9));
  });

  test('optional lines are left out, not guessed', () {
    final p = CostProfile(
        fuelPricePerLitre: 165, kmPerLitre: 50, purchasePrice: 100000);
    expect(p.lines.map((l) => l.kind), [CostKind.fuel]);
    expect(p.trip(pickupKm: 0, tripKm: 0).unpaidShare, 0);
  });

  test('bad input is refused at the boundary', () {
    expect(() => CostProfile(fuelPricePerLitre: 165, kmPerLitre: 0),
        throwsArgumentError);
    expect(() => CostProfile(fuelPricePerLitre: -1, kmPerLitre: 40),
        throwsArgumentError);
    expect(() => CostProfile(fuelPricePerLitre: double.nan, kmPerLitre: 40),
        throwsArgumentError);
    expect(
        () => CostProfile(
            fuelPricePerLitre: 165,
            kmPerLitre: 40,
            purchasePrice: 1,
            resaleValue: 2),
        throwsArgumentError);
    expect(
        () => CostProfile(
            fuelPricePerLitre: 165, kmPerLitre: 40, commissionRate: 1),
        throwsArgumentError);
    expect(() => MaintenanceItem(name: 'x', cost: 10, intervalKm: 0),
        throwsArgumentError);
    expect(() => scooter().trip(pickupKm: -1, tripKm: 2), throwsArgumentError);
    expect(() => scooter().trip(pickupKm: 1, tripKm: 2, fare: double.infinity),
        throwsArgumentError);
  });

  test('toJson carries the breakdown', () {
    final j =
        scooter().trip(pickupKm: 3, tripKm: 8, homeKm: 6, fare: 150).toJson();
    expect(j['totalCost'], isA<double>());
    expect((j['breakdown'] as List).first, containsPair('kind', 'fuel'));
    expect(j['netEarnings'], isA<double>());
  });
}
