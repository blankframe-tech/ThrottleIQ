import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/fuel_units.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

MaintenanceEntity _log(ServiceType t, double? cost, {String id = 'x'}) =>
    MaintenanceEntity(
      id: id,
      bikeId: 'b',
      serviceType: t,
      date: DateTime(2026, 1, 1),
      odometerKm: 1000,
      cost: cost,
      createdAt: DateTime(2026, 1, 1),
    );

MaintenanceConfigEntity _cfg(ServiceType t, double interval,
        {double? typical, bool enabled = true}) =>
    MaintenanceConfigEntity(
      bikeId: 'b',
      serviceType: t,
      intervalKm: interval,
      isEnabled: enabled,
      typicalCost: typical,
    );

void main() {
  group('fuelCostPerKm', () {
    test('price per litre / km per litre', () {
      expect(RideCostCalculator.fuelCostPerKm(pricePerLitre: 125, kmPerLitre: 50),
          closeTo(2.5, 1e-9));
    });
    test('null when either input missing or non-positive', () {
      expect(RideCostCalculator.fuelCostPerKm(pricePerLitre: 125), isNull);
      expect(RideCostCalculator.fuelCostPerKm(kmPerLitre: 40), isNull);
      expect(RideCostCalculator.fuelCostPerKm(pricePerLitre: 0, kmPerLitre: 40),
          isNull);
      expect(RideCostCalculator.fuelCostPerKm(pricePerLitre: 125, kmPerLitre: 0),
          isNull);
    });
  });

  group('itemCostPerKm', () {
    test('falls back to typical cost / interval', () {
      final r = RideCostCalculator.itemCostPerKm(
          intervalKm: 1500, typicalCost: 900);
      expect(r!.costPerKm, closeTo(0.6, 1e-9));
      expect(r.source, CostSource.typical);
    });

    test('prefers the average of logged actual costs', () {
      final r = RideCostCalculator.itemCostPerKm(
        intervalKm: 1000,
        typicalCost: 5000,
        logs: [
          _log(ServiceType.oilChange, 800),
          _log(ServiceType.oilChange, 1200),
          // Uncosted and zero-cost logs don't drag the average down.
          _log(ServiceType.oilChange, null),
          _log(ServiceType.oilChange, 0),
        ],
      );
      expect(r!.costPerKm, closeTo(1.0, 1e-9));
      expect(r.source, CostSource.history);
    });

    test('null without any cost data or with a zero interval', () {
      expect(RideCostCalculator.itemCostPerKm(intervalKm: 1000), isNull);
      expect(
          RideCostCalculator.itemCostPerKm(intervalKm: 0, typicalCost: 500),
          isNull);
    });
  });

  group('compute', () {
    test('fuel + tracked items, scaled by distance, most expensive first', () {
      final b = RideCostCalculator.compute(
        distanceKm: 20,
        runningCost: const BikeRunningCostEntity(
            bikeId: 'b', fuelPricePerLitre: 125, kmPerLitre: 50), // 2.5/km
        configs: [
          _cfg(ServiceType.oilChange, 1500, typical: 900), // 0.6/km
          _cfg(ServiceType.chain, 600, typical: 120), // 0.2/km
          _cfg(ServiceType.tire, 3000), // no data → skipped
        ],
        logs: const [],
      );
      expect(b.lines.map((l) => l.serviceType), [
        ServiceType.fuel,
        ServiceType.oilChange,
        ServiceType.chain,
      ]);
      expect(b.costPerKm, closeTo(3.3, 1e-9));
      expect(b.total, closeTo(66, 1e-9));
      expect(b.lines.first.cost, closeTo(50, 1e-9));
      expect(b.lines.first.source, CostSource.fuel);
    });

    test('disabled checks, the fuel check and custom are never itemised', () {
      final b = RideCostCalculator.compute(
        distanceKm: 10,
        configs: [
          _cfg(ServiceType.oilChange, 1000, typical: 1000, enabled: false),
          _cfg(ServiceType.fuel, 300, typical: 1500),
          _cfg(ServiceType.custom, 1000, typical: 1000),
        ],
        logs: [_log(ServiceType.oilChange, 1000)],
      );
      expect(b.isEmpty, isTrue);
      expect(b.total, 0);
    });

    test('logs of other types do not leak into an item', () {
      final b = RideCostCalculator.compute(
        distanceKm: 100,
        configs: [_cfg(ServiceType.chain, 500, typical: 100)],
        logs: [_log(ServiceType.oilChange, 5000)],
      );
      expect(b.lines.single.source, CostSource.typical);
      expect(b.total, closeTo(20, 1e-9));
    });

    test('zero, negative or non-finite distance costs nothing', () {
      for (final d in [0.0, -5.0, double.nan]) {
        final b = RideCostCalculator.compute(
          distanceKm: d,
          configs: [_cfg(ServiceType.chain, 500, typical: 100)],
          logs: const [],
        );
        expect(b.total, 0);
        // The rate is still known — only the distance is zero.
        expect(b.costPerKm, closeTo(0.2, 1e-9));
      }
    });
  });

  group('FuelUnits', () {
    test('mpg ↔ km/l round-trips', () {
      expect(FuelUnits.mpgToKmPerLitre(100), closeTo(42.514, 1e-3));
      expect(FuelUnits.kmPerLitreToMpg(FuelUnits.mpgToKmPerLitre(87)),
          closeTo(87, 1e-9));
    });
    test('price per gallon ↔ per litre round-trips', () {
      expect(FuelUnits.pricePerGallonToPerLitre(3.785411784), closeTo(1, 1e-9));
      expect(
          FuelUnits.pricePerLitreToPerGallon(
              FuelUnits.pricePerGallonToPerLitre(470)),
          closeTo(470, 1e-9));
    });
    test('per-km rate to per-mile', () {
      expect(FuelUnits.costPerKmToPerMile(1), closeTo(1.609344, 1e-9));
    });
  });
}
