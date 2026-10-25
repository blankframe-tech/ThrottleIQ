import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_cost_calculator.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/ride_fuel.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

/// [km] ridden at [kmh] while moving, plus [idleMin] minutes stopped.
UsageStats _ride(double km, double kmh, {double idleMin = 0}) {
  final moving = (km / kmh * 3600).round();
  return UsageStats(
    rideDistanceKm: km,
    movingSeconds: moving,
    durationSeconds: moving + (idleMin * 60).round(),
  );
}

void main() {
  group('speedFuelFactor', () {
    test('best at a steady 40–55 km/h, worse crawling or fast', () {
      expect(speedFuelFactor(45), 1.0);
      expect(speedFuelFactor(15), closeTo(1.45, 1e-9));
      expect(speedFuelFactor(5), 1.6);
      expect(speedFuelFactor(80), closeTo(1.2, 1e-9));
      expect(speedFuelFactor(150), 1.3);
    });
  });

  group('rideFuelFactor', () {
    // 30 km/h moving, 10 min stopped per 10 km.
    final usual = _ride(300, 30, idleMin: 300);

    test('a ride like the usual one costs the rider\'s own km/L', () {
      expect(
          rideFuelFactor(
              ride: _ride(10, 30, idleMin: 10), usual: usual, kmPerLitre: 45),
          closeTo(1.0, 1e-9));
    });

    test('a jam ride burns more, a steady cruise less', () {
      final jam = rideFuelFactor(
          ride: _ride(10, 12, idleMin: 30), usual: usual, kmPerLitre: 45)!;
      final cruise =
          rideFuelFactor(ride: _ride(10, 45), usual: usual, kmPerLitre: 45)!;
      expect(jam, greaterThan(1.4));
      expect(cruise, lessThan(0.95));
    });

    test('stopped time alone adds fuel, more on a bigger engine', () {
      final calm = rideFuelFactor(
          ride: _ride(10, 30, idleMin: 10), usual: usual, kmPerLitre: 45)!;
      final stuck = rideFuelFactor(
          ride: _ride(10, 30, idleMin: 40), usual: usual, kmPerLitre: 45)!;
      final stuckBig = rideFuelFactor(
          ride: _ride(10, 30, idleMin: 40),
          usual: usual,
          kmPerLitre: 45,
          cc: 400)!;
      expect(stuck, greaterThan(calm));
      expect(stuckBig, greaterThan(stuck));
    });

    test('null without enough history, timing or km/L', () {
      final ride = _ride(10, 30);
      expect(rideFuelFactor(ride: ride, usual: _ride(50, 30), kmPerLitre: 45),
          isNull);
      expect(
          rideFuelFactor(
              ride: const UsageStats(rideDistanceKm: 10),
              usual: usual,
              kmPerLitre: 45),
          isNull);
      expect(rideFuelFactor(ride: ride, usual: usual, kmPerLitre: 0), isNull);
    });

    test('clamped against GPS nonsense', () {
      expect(
          rideFuelFactor(
              ride: _ride(0.5, 5, idleMin: 120), usual: usual, kmPerLitre: 45),
          kMaxRideFuelFactor);
    });
  });

  test('compute scales only the fuel line by fuelFactor', () {
    final b = RideCostCalculator.compute(
      distanceKm: 20,
      configs: const [
        MaintenanceConfigEntity(
            bikeId: 'b',
            serviceType: ServiceType.oilChange,
            intervalKm: 1500,
            typicalCost: 900),
      ],
      logs: const [],
      runningCost: const BikeRunningCostEntity(
          bikeId: 'b', fuelPricePerLitre: 125, kmPerLitre: 50),
      fuelFactor: 1.5,
    );
    expect(b.fuelFactor, 1.5);
    expect(b.lines.firstWhere((l) => l.serviceType == ServiceType.fuel).cost,
        closeTo(75, 1e-9));
    expect(
        b.lines.firstWhere((l) => l.serviceType == ServiceType.oilChange).cost,
        closeTo(12, 1e-9));
  });
}
