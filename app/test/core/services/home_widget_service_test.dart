import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/home_widget_service.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

MaintenanceEntity _log(ServiceType type, double odometerKm) => MaintenanceEntity(
      id: '$type-$odometerKm',
      bikeId: 'bike-1',
      serviceType: type,
      date: DateTime(2026, 1, 1),
      odometerKm: odometerKm,
      createdAt: DateTime(2026, 1, 1),
    );

RideEntity _ride({required DateTime startTime, required double distanceM}) =>
    RideEntity(
      id: 'r-${startTime.microsecondsSinceEpoch}',
      userId: 'u1',
      bikeId: 'bike-1',
      startTime: startTime,
      distanceM: distanceM,
      status: RideStatus.completed,
    );

void main() {
  group('formatKm', () {
    test('zero and near-zero collapse to a clean "0 km"', () {
      expect(formatKm(0), '0 km');
      expect(formatKm(0.0), '0 km');
      // Below the one-decimal resolution — "0.0 km" would look broken.
      expect(formatKm(0.04), '0 km');
    });

    test('one decimal below 1000 km', () {
      expect(formatKm(0.05), '0.1 km');
      expect(formatKm(1), '1.0 km');
      expect(formatKm(128.4), '128.4 km');
      expect(formatKm(999.9), '999.9 km');
    });

    test('rounds to one decimal rather than truncating', () {
      expect(formatKm(128.44), '128.4 km');
      expect(formatKm(128.46), '128.5 km');
      expect(formatKm(12.349), '12.3 km');
    });

    test('whole kilometres with thousands separators at and above 1000', () {
      expect(formatKm(1000), '1,000 km');
      expect(formatKm(1000.6), '1,001 km');
      expect(formatKm(12480.3), '12,480 km');
    });

    test('very large values stay readable', () {
      expect(formatKm(999999.4), '999,999 km');
      expect(formatKm(1234567.89), '1,234,568 km');
      expect(formatKm(1000000000), '1,000,000,000 km');
    });

    test('negative and non-finite inputs never render NaN on a home screen', () {
      expect(formatKm(-1), '0 km');
      expect(formatKm(-9999), '0 km');
      expect(formatKm(double.nan), '0 km');
      expect(formatKm(double.infinity), '0 km');
      expect(formatKm(double.negativeInfinity), '0 km');
    });
  });

  group('formatRideCount', () {
    test('pluralises and clamps', () {
      expect(formatRideCount(0), '0 rides');
      expect(formatRideCount(1), '1 ride');
      expect(formatRideCount(2), '2 rides');
      expect(formatRideCount(351), '351 rides');
      expect(formatRideCount(-4), '0 rides');
    });
  });

  group('formatNextServiceSummary', () {
    test('due-soon wording counts down to the limit', () {
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Oil Change',
          kmUntilDue: 240,
          overdue: false,
        ),
        'Oil Change in 240.0 km',
      );
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Chain Lube',
          kmUntilDue: 1200.4,
          overdue: false,
        ),
        'Chain Lube in 1,200 km',
      );
    });

    test('overdue wording counts up past the limit', () {
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Oil Change',
          kmUntilDue: -240,
          overdue: true,
        ),
        'Oil Change overdue by 240.0 km',
      );
    });

    test('overdue uses the flag, not the sign, so magnitude also works', () {
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Tire Check',
          kmUntilDue: 80,
          overdue: true,
        ),
        'Tire Check overdue by 80.0 km',
      );
    });

    test('exactly at the limit but not flagged overdue reads as due now', () {
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Air Filter',
          kmUntilDue: 0,
          overdue: false,
        ),
        'Air Filter due now',
      );
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Air Filter',
          kmUntilDue: -5,
          overdue: false,
        ),
        'Air Filter due now',
      );
    });

    test('blank label falls back rather than rendering a leading space', () {
      expect(
        formatNextServiceSummary(
          serviceLabel: '   ',
          kmUntilDue: 100,
          overdue: false,
        ),
        'Service in 100.0 km',
      );
      expect(
        formatNextServiceSummary(
          serviceLabel: '  Brake Fluid  ',
          kmUntilDue: 100,
          overdue: false,
        ),
        'Brake Fluid in 100.0 km',
      );
    });

    test('NaN distance degrades to "due now" instead of "in NaN km"', () {
      expect(
        formatNextServiceSummary(
          serviceLabel: 'Oil Change',
          kmUntilDue: double.nan,
          overdue: false,
        ),
        'Oil Change due now',
      );
    });
  });

  group('weeklyDistanceKm', () {
    final now = DateTime(2026, 8, 1, 12);

    test('is zero with no rides', () {
      expect(weeklyDistanceKm(const [], now: now), 0);
    });

    test('sums only the rolling last 7 days', () {
      final rides = [
        _ride(startTime: now.subtract(const Duration(days: 1)), distanceM: 40000),
        _ride(startTime: now.subtract(const Duration(days: 6)), distanceM: 15500),
        // Older than the window — excluded.
        _ride(startTime: now.subtract(const Duration(days: 8)), distanceM: 90000),
      ];
      expect(weeklyDistanceKm(rides, now: now), closeTo(55.5, 1e-9));
    });
  });

  group('computeNextService', () {
    test('a bike with no logs is measured from zero and picks the tightest '
        'interval', () {
      final next = computeNextService(currentOdometerKm: 0, logs: const []);
      // Chain lube has the shortest limit (700 km) of the reminder types.
      expect(next, isNotNull);
      expect(next!.serviceType, ServiceType.chain);
      expect(next.overdue, isFalse);
      expect(next.kmUntilDue, 700);
    });

    test('overdue once past the limit, reported as negative remaining', () {
      final next = computeNextService(
        currentOdometerKm: 2000,
        logs: [_log(ServiceType.chain, 1900)],
      );
      expect(next, isNotNull);
      // Oil change was never logged: 2000 km since, limit 1500 -> -500.
      expect(next!.serviceType, ServiceType.oilChange);
      expect(next.overdue, isTrue);
      expect(next.kmUntilDue, -500);
      expect(
        formatNextServiceSummary(
          serviceLabel: next.label,
          kmUntilDue: next.kmUntilDue,
          overdue: next.overdue,
        ),
        'Oil Change overdue by 500.0 km',
      );
    });

    test('the most overdue item wins over a merely due-soon one', () {
      final next = computeNextService(
        currentOdometerKm: 10000,
        logs: [
          _log(ServiceType.oilChange, 9200), // 800 since, 700 left
          _log(ServiceType.chain, 9000), // 1000 since, limit 700 -> -300
          _log(ServiceType.airFilter, 9990),
          _log(ServiceType.tire, 9990),
          _log(ServiceType.brakeFluid, 9990),
          _log(ServiceType.frontDiscPads, 9990),
        ],
      );
      expect(next!.serviceType, ServiceType.chain);
      expect(next.overdue, isTrue);
      expect(next.kmUntilDue, -300);
    });

    test('a freshly serviced bike still reports the next thing due', () {
      final next = computeNextService(
        currentOdometerKm: 5000,
        logs: [
          for (final t in kWidgetReminderTypes) _log(t, 5000),
        ],
      );
      expect(next!.overdue, isFalse);
      expect(next.serviceType, ServiceType.chain);
      expect(next.kmUntilDue, 700);
    });

    test('log-only service types are ignored entirely', () {
      final next = computeNextService(
        currentOdometerKm: 100,
        logs: [_log(ServiceType.valveClearance, 0)],
      );
      expect(next, isNotNull);
      expect(kWidgetReminderTypes.contains(next!.serviceType), isTrue);
    });
  });

  group('HomeWidgetService.isStartRideUri', () {
    test('matches the start-ride URI', () {
      expect(
        HomeWidgetService.isStartRideUri(Uri.parse('throttleiq://startride')),
        isTrue,
      );
    });

    // Android and iOS differ on trailing-slash handling, which is exactly why
    // this compares scheme + host instead of the whole string.
    test('matches regardless of a trailing slash or query', () {
      expect(
        HomeWidgetService.isStartRideUri(Uri.parse('throttleiq://startride/')),
        isTrue,
      );
      expect(
        HomeWidgetService.isStartRideUri(
            Uri.parse('throttleiq://startride?src=widget')),
        isTrue,
      );
    });

    test('rejects null — a normal icon launch has no URI', () {
      expect(HomeWidgetService.isStartRideUri(null), isFalse);
    });

    test('rejects a different host on the same scheme', () {
      expect(
        HomeWidgetService.isStartRideUri(Uri.parse('throttleiq://stats')),
        isFalse,
      );
    });

    test('rejects a foreign scheme, even with a matching host', () {
      expect(
        HomeWidgetService.isStartRideUri(Uri.parse('https://startride')),
        isFalse,
      );
      expect(
        HomeWidgetService.isStartRideUri(Uri.parse('evil://startride')),
        isFalse,
      );
    });

    test('the advertised URI constant is the one that matches', () {
      expect(
        HomeWidgetService.isStartRideUri(HomeWidgetService.startRideUri),
        isTrue,
      );
    });

    test('rejects the auto-tracking URI — the two must not cross-fire', () {
      expect(
        HomeWidgetService.isStartRideUri(
            Uri.parse('throttleiq://autotracking')),
        isFalse,
      );
    });
  });

  group('HomeWidgetService.isAutoTrackingUri', () {
    test('matches the auto-tracking URI', () {
      expect(
        HomeWidgetService.isAutoTrackingUri(
            Uri.parse('throttleiq://autotracking')),
        isTrue,
      );
    });

    test('matches regardless of a trailing slash or query', () {
      expect(
        HomeWidgetService.isAutoTrackingUri(
            Uri.parse('throttleiq://autotracking/')),
        isTrue,
      );
      expect(
        HomeWidgetService.isAutoTrackingUri(
            Uri.parse('throttleiq://autotracking?src=widget')),
        isTrue,
      );
    });

    test('rejects null — a normal icon launch has no URI', () {
      expect(HomeWidgetService.isAutoTrackingUri(null), isFalse);
    });

    test('rejects the start-ride URI — the two must not cross-fire', () {
      expect(
        HomeWidgetService.isAutoTrackingUri(
            Uri.parse('throttleiq://startride')),
        isFalse,
      );
    });

    test('rejects a foreign scheme, even with a matching host', () {
      expect(
        HomeWidgetService.isAutoTrackingUri(
            Uri.parse('https://autotracking')),
        isFalse,
      );
    });

    test('the advertised URI constant is the one that matches', () {
      expect(
        HomeWidgetService.isAutoTrackingUri(
            HomeWidgetService.autoTrackingUri),
        isTrue,
      );
    });
  });

  group('homeWidgetServiceProvider & refreshWithData', () {
    test('homeWidgetServiceProvider provides the HomeWidgetService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(homeWidgetServiceProvider), same(HomeWidgetService.instance));
    });

    test('refreshWithData runs safely without throwing when widgets are unplaced', () async {
      final service = HomeWidgetService();
      await service.refreshWithData(rides: [], bikes: []);
    });
  });
}
