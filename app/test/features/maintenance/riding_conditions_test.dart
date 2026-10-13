import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

void main() {
  UsageStats usage({
    double km = 500,
    int moving = 6000,
    int duration = 10000,
    int brakes = 0,
  }) =>
      UsageStats(
        rideDistanceKm: km,
        movingSeconds: moving,
        durationSeconds: duration,
        hardBrakes: brakes,
      );

  test('heavy stop-and-go (40% idle) shortens oil by 20% and says why', () {
    final c = deriveConditions(
        usage: usage(moving: 6000, duration: 10000),
        profile: RidingProfile.normal);
    expect(c.factorFor(ServiceType.oilChange), closeTo(0.8, 1e-9));
    final r = c.reasonsFor(ServiceType.oilChange).single;
    expect(r.kind, AdaptReasonKind.stopAndGo);
    expect(r.measure, closeTo(0.4, 1e-9));
    expect(r.percentShorter, 20);
    // Not a brake or chain item.
    expect(c.factorFor(ServiceType.chain), 1.0);
  });

  test('moderate traffic (25% idle) is 10%; light traffic nothing', () {
    expect(
        deriveConditions(
                usage: usage(moving: 7500, duration: 10000),
                profile: RidingProfile.normal)
            .factorFor(ServiceType.oilChange),
        closeTo(0.9, 1e-9));
    expect(
        deriveConditions(
                usage: usage(moving: 9000, duration: 10000),
                profile: RidingProfile.normal)
            .isEmpty,
        isTrue);
  });

  test('too little riding means no telemetry adjustment at all', () {
    final c = deriveConditions(
        usage: usage(km: 40, moving: 1000, duration: 10000, brakes: 50),
        profile: RidingProfile.normal);
    expect(c.isEmpty, isTrue);
  });

  test('hard braking ≥ 3 per 100 km wears pads sooner', () {
    final c = deriveConditions(
        usage: usage(km: 400, moving: 10000, duration: 10000, brakes: 16),
        profile: RidingProfile.normal);
    expect(c.factorFor(ServiceType.frontDiscPads), closeTo(0.85, 1e-9));
    expect(c.factorFor(ServiceType.oilChange), 1.0);
  });

  test('factors combine but never below 70%', () {
    final c = deriveConditions(
        usage: usage(moving: 5000, duration: 10000),
        profile: RidingProfile.severe);
    // Severe roads alone are 0.7 for the air filter.
    expect(c.factorFor(ServiceType.airFilter), closeTo(0.7, 1e-9));
    expect(c.factorFor(ServiceType.chain), closeTo(0.7, 1e-9));
    const many = ConditionProfile({
      ServiceType.oilChange: [
        AdaptReason(AdaptReasonKind.stopAndGo, 0.8),
        AdaptReason(AdaptReasonKind.severeRoads, 0.7),
      ],
    });
    expect(many.factorFor(ServiceType.oilChange), kMinConditionFactor);
  });
}
