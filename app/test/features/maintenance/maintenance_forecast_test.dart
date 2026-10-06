import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

/// The one maintenance engine (issues §95): km or time, whichever first;
/// honest unknowns; projected dates; condition-adapted intervals.
void main() {
  final now = DateTime(2026, 10, 6, 12);

  MaintenanceConfigEntity cfg(
    ServiceType t, {
    double km = 0,
    int? days,
    double? baselineKm,
    DateTime? baselineDate,
    bool enabled = true,
  }) =>
      MaintenanceConfigEntity(
        bikeId: 'b',
        serviceType: t,
        intervalKm: km,
        intervalDays: days,
        baselineKm: baselineKm,
        baselineDate: baselineDate,
        isEnabled: enabled,
      );

  MaintenanceEntity log(ServiceType t, double km, DateTime date,
          {String? checkKey}) =>
      MaintenanceEntity(
        id: '$t-$km',
        bikeId: 'b',
        serviceType: t,
        date: date,
        odometerKm: km,
        createdAt: date,
        checkKey: checkKey,
      );

  ForecastInput input(double odo,
          {double? avg,
          ConditionProfile conditions = ConditionProfile.none,
          bool adapt = true,
          ({double km, DateTime date})? fallback}) =>
      ForecastInput(
        currentOdometerKm: odo,
        now: now,
        avgDailyKm: avg,
        conditions: conditions,
        adapt: adapt,
        fallbackBaseline: fallback,
      );

  group('km or time, whichever first', () {
    test('a parked bike still comes due by date', () {
      final f = forecastOne(
        cfg(ServiceType.oilChange, km: 1500, days: 180),
        [log(ServiceType.oilChange, 10000, DateTime(2026, 3, 1))],
        input(10050), // barely ridden
      );
      expect(f.kmLeft, closeTo(1450, 1e-9));
      expect(f.daysLeft, lessThan(0));
      expect(f.status, ReminderStatus.overdue);
    });

    test('a ridden bike comes due by km before the date', () {
      final f = forecastOne(
        cfg(ServiceType.oilChange, km: 1500, days: 180),
        [log(ServiceType.oilChange, 10000, DateTime(2026, 9, 1))],
        input(11600),
      );
      expect(f.kmLeft, closeTo(-100, 1e-9));
      expect(f.status, ReminderStatus.overdue);
    });

    test('time-only check (no km interval)', () {
      final f = forecastOne(
        cfg(ServiceType.battery, days: 365),
        [log(ServiceType.battery, 5000, DateTime(2026, 9, 6))],
        input(9000),
      );
      expect(f.kmLeft, isNull);
      expect(f.daysLeft, 335);
      expect(f.status, ReminderStatus.ok);
      expect(f.trigger, DueTrigger.time);
    });

    test('the due day is due soon; the day after is overdue', () {
      MaintenanceEntity done(DateTime d) => log(ServiceType.battery, 0, d);
      final dueToday = forecastOne(cfg(ServiceType.battery, days: 365),
          [done(DateTime(2025, 10, 6))], input(10));
      expect(dueToday.daysLeft, 0);
      expect(dueToday.status, ReminderStatus.dueSoon);
      final pastDue = forecastOne(cfg(ServiceType.battery, days: 365),
          [done(DateTime(2025, 10, 5))], input(10));
      expect(pastDue.status, ReminderStatus.overdue);
    });

    test('due soon inside the default day window', () {
      // 730 days → 30-day window (capped).
      final f = forecastOne(
        cfg(ServiceType.brakeFluid, days: 730),
        [log(ServiceType.brakeFluid, 0, DateTime(2024, 10, 26))],
        input(100),
      );
      expect(f.daysLeft, 20);
      expect(f.status, ReminderStatus.dueSoon);
    });

    test('rider-set warning windows override the defaults', () {
      final f = forecastOne(
        const MaintenanceConfigEntity(
          bikeId: 'b',
          serviceType: ServiceType.chain,
          intervalKm: 600,
          warnKm: 50,
        ),
        [log(ServiceType.chain, 1000, now)],
        input(1500), // 100 left: default window would say due soon
      );
      expect(f.status, ReminderStatus.ok);
    });
  });

  group('where a check counts from', () {
    test('no log, no baseline, no fallback → unknown, not overdue', () {
      // A bike added at 25,000 km used to light up every check red (§94.3).
      final f = forecastOne(cfg(ServiceType.airFilter, km: 8000), const [],
          input(25000));
      expect(f.status, ReminderStatus.unknown);
      expect(f.kmSince, isNull);
    });

    test('the rider\'s "last done" baseline is used when nothing is logged', () {
      final f = forecastOne(
        cfg(ServiceType.oilChange,
            km: 2000, baselineKm: 24000, baselineDate: DateTime(2026, 9, 1)),
        const [],
        input(25000),
      );
      expect(f.kmSince, 1000);
      expect(f.fromBaseline, isTrue);
      expect(f.status, ReminderStatus.ok);
    });

    test('a real log wins over the baseline', () {
      final f = forecastOne(
        cfg(ServiceType.oilChange, km: 2000, baselineKm: 20000),
        [log(ServiceType.oilChange, 24800, now)],
        input(25000),
      );
      expect(f.kmSince, 200);
      expect(f.fromBaseline, isFalse);
    });

    test('a new bike counts from when it was added', () {
      final f = forecastOne(cfg(ServiceType.chain, km: 600), const [],
          input(300, fallback: (km: 0, date: DateTime(2026, 9, 1))));
      expect(f.kmSince, 300);
      expect(f.status, ReminderStatus.ok);
    });

    test('custom checks count only their own logs', () {
      const custom = MaintenanceConfigEntity(
        bikeId: 'b',
        serviceType: ServiceType.custom,
        customId: 'x',
        customLabel: 'Steering bearings',
        intervalKm: 5000,
      );
      final f = forecastOne(
        custom,
        [
          log(ServiceType.custom, 9000, now), // a one-off job, not this check
          log(ServiceType.custom, 4000, now, checkKey: 'custom:x'),
        ],
        input(9500),
      );
      expect(f.kmSince, 5500);
      expect(f.status, ReminderStatus.overdue);
    });
  });

  group('newBikeBaseline', () {
    final added = DateTime(2026, 1, 1);
    test('near-new bike counts from its starting reading', () {
      final b = newBikeBaseline(
          baselineOdometerKm: 120, creditedKm: 0, addedAt: added);
      expect(b!.km, 120);
      expect(b.date, added);
    });

    test('detected-trip credits are not mistaken for history', () {
      final b = newBikeBaseline(
          baselineOdometerKm: 900, creditedKm: 800, addedAt: added);
      expect(b!.km, closeTo(100, 1e-9));
    });

    test('a bike added with real mileage has no fallback', () {
      expect(
          newBikeBaseline(
              baselineOdometerKm: 25000, creditedKm: 0, addedAt: added),
          isNull);
    });
  });

  group('projection', () {
    test('km left ÷ daily pace gives the date', () {
      final f = forecastOne(
        cfg(ServiceType.oilChange, km: 1500),
        [log(ServiceType.oilChange, 1000, now)],
        input(2090, avg: 68.3), // 410 km left
      );
      expect(f.daysUntilDue(now), 6);
      expect(f.trigger, DueTrigger.km);
    });

    test('without a riding pace there is no km date', () {
      final f = forecastOne(cfg(ServiceType.oilChange, km: 1500),
          [log(ServiceType.oilChange, 1000, now)], input(1100));
      expect(f.dueDate, isNull);
    });

    test('the earlier of km and time is the due date', () {
      final f = forecastOne(
        cfg(ServiceType.oilChange, km: 1500, days: 30),
        [log(ServiceType.oilChange, 1000, DateTime(2026, 10, 1))],
        input(1100, avg: 10), // km in 140 days, time in 25
      );
      expect(f.trigger, DueTrigger.time);
      expect(f.daysUntilDue(now), 25);
    });
  });

  group('adaptation', () {
    final severe = deriveConditions(
        usage: UsageStats.empty, profile: RidingProfile.severe);

    test('severe roads shorten the air filter and explain why', () {
      final f = forecastOne(
        cfg(ServiceType.airFilter, km: 8000),
        [log(ServiceType.airFilter, 0, now)],
        input(1000, conditions: severe),
      );
      expect(f.kmLimit, closeTo(5600, 1e-9));
      expect(f.baseKmLimit, 8000);
      expect(f.isAdapted, isTrue);
      expect(f.reasons.single.kind, AdaptReasonKind.severeRoads);
    });

    test('switching adaptation off restores the configured interval', () {
      final f = forecastOne(
        cfg(ServiceType.airFilter, km: 8000),
        [log(ServiceType.airFilter, 0, now)],
        input(1000, conditions: severe, adapt: false),
      );
      expect(f.kmLimit, 8000);
      expect(f.reasons, isEmpty);
    });

    test('time limits are not scaled', () {
      final f = forecastOne(
        cfg(ServiceType.chain, km: 600, days: 30),
        [log(ServiceType.chain, 0, now)],
        input(0, conditions: severe),
      );
      expect(f.daysLimit, 30);
    });
  });

  group('ordering and headline', () {
    test('overdue first, then by due date, unknown last; disabled skipped', () {
      final list = forecastChecks(
        configs: [
          cfg(ServiceType.airFilter, km: 8000), // unknown (no baseline)
          cfg(ServiceType.chain, km: 600, baselineKm: 0, baselineDate: now),
          cfg(ServiceType.oilChange, km: 1500, baselineKm: 0, baselineDate: now),
          cfg(ServiceType.tire, km: 100, baselineKm: 0, baselineDate: now),
          cfg(ServiceType.sparkPlug, km: 1, enabled: false),
        ],
        logs: const [],
        input: input(500, avg: 50),
      );
      expect(list.map((f) => f.serviceType), [
        ServiceType.tire, // overdue
        ServiceType.chain, // 100 left, due soon
        ServiceType.oilChange, // 1000 left
        ServiceType.airFilter, // unknown
      ]);
    });

    test('upNext skips fuel and unknown items', () {
      final list = forecastChecks(
        configs: [
          cfg(ServiceType.fuel, km: 300, baselineKm: 0),
          cfg(ServiceType.airFilter, km: 8000),
          cfg(ServiceType.chain, km: 600, baselineKm: 0),
        ],
        logs: const [],
        input: input(400),
      );
      expect(upNext(list)!.serviceType, ServiceType.chain);
      expect(upNext(const []), isNull);
    });
  });
}
