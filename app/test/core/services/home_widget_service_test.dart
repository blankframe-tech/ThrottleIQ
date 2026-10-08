import 'package:flutter/material.dart' show Brightness, Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/home_widget_service.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

MaintenanceEntity _log(ServiceType type, double odometerKm) =>
    MaintenanceEntity(
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

    test('negative and non-finite inputs never render NaN on a home screen',
        () {
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
        _ride(
            startTime: now.subtract(const Duration(days: 1)), distanceM: 40000),
        _ride(
            startTime: now.subtract(const Duration(days: 6)), distanceM: 15500),
        // Older than the window — excluded.
        _ride(
            startTime: now.subtract(const Duration(days: 8)), distanceM: 90000),
      ];
      expect(weeklyDistanceKm(rides, now: now), closeTo(55.5, 1e-9));
    });
  });

  group('nextServiceDue (shared forecast engine, §94.1)', () {
    final now = DateTime(2026, 10, 6);
    MaintenanceConfigEntity cfg(ServiceType t, double km, [int? days]) =>
        MaintenanceConfigEntity(
            bikeId: 'bike-1',
            serviceType: t,
            intervalKm: km,
            intervalDays: days);
    List<CheckForecast> forecast(double odo, List<MaintenanceEntity> logs,
            List<MaintenanceConfigEntity> configs) =>
        forecastChecks(
          configs: configs,
          logs: logs,
          input: ForecastInput(
            currentOdometerKm: odo,
            now: now,
            fallbackBaseline: (km: 0, date: now),
          ),
        );

    test('follows the rider\'s own intervals, not a separate table', () {
      // A 3,000 km tyre interval used to read 8,000 on the widget.
      final next = nextServiceDue(forecast(2900, const [], [
        cfg(ServiceType.tire, 3000),
        cfg(ServiceType.oilChange, 5000),
      ]));
      expect(next!.serviceType, ServiceType.tire);
      expect(next.kmUntilDue, closeTo(100, 1e-9));
      expect(next.overdue, isFalse);
    });

    test('overdue reported as negative remaining and worded as overdue', () {
      final next = nextServiceDue(forecast(
        2000,
        [_log(ServiceType.chain, 1900)],
        [cfg(ServiceType.oilChange, 1500), cfg(ServiceType.chain, 700)],
      ));
      expect(next!.serviceType, ServiceType.oilChange);
      expect(next.overdue, isTrue);
      expect(next.kmUntilDue, -500);
      expect(
        formatNextServiceSummary(
          serviceLabel: next.label,
          kmUntilDue: next.kmUntilDue!,
          overdue: next.overdue,
        ),
        'Oil Change overdue by 500.0 km',
      );
    });

    test('disabled checks and fuel never headline', () {
      final next = nextServiceDue(forecast(10000, const [], [
        cfg(ServiceType.fuel, 300),
        const MaintenanceConfigEntity(
            bikeId: 'bike-1',
            serviceType: ServiceType.valveClearance,
            intervalKm: 100,
            isEnabled: false),
        cfg(ServiceType.airFilter, 20000),
      ]));
      expect(next!.serviceType, ServiceType.airFilter);
    });

    test('a time-driven item is worded in days', () {
      final next = nextServiceDue(forecastChecks(
        configs: [cfg(ServiceType.brakeFluid, 0, 730)],
        logs: [
          MaintenanceEntity(
            id: 'bf',
            bikeId: 'bike-1',
            serviceType: ServiceType.brakeFluid,
            date: DateTime(2024, 10, 16),
            odometerKm: 0,
            createdAt: DateTime(2024, 10, 16),
          ),
        ],
        input: ForecastInput(currentOdometerKm: 100, now: now),
      ));
      expect(next!.byTime, isTrue);
      expect(next.daysUntilDue, 10);
      expect(
        formatNextServiceSummary(
          serviceLabel: next.label,
          kmUntilDue: 0,
          overdue: next.overdue,
          daysUntilDue: next.daysUntilDue,
        ),
        'Brake Fluid in 10 days',
      );
    });

    test('nothing tracked means nothing to say', () {
      expect(nextServiceDue(const []), isNull);
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
        HomeWidgetService.isAutoTrackingUri(Uri.parse('https://autotracking')),
        isFalse,
      );
    });

    test('the advertised URI constant is the one that matches', () {
      expect(
        HomeWidgetService.isAutoTrackingUri(HomeWidgetService.autoTrackingUri),
        isTrue,
      );
    });
  });

  group('HomeWidgetService.isApexHunterUri', () {
    test('matches the apex hunter URI', () {
      expect(
        HomeWidgetService.isApexHunterUri(Uri.parse('throttleiq://apexhunter')),
        isTrue,
      );
    });

    test('matches regardless of trailing slash or query', () {
      expect(
        HomeWidgetService.isApexHunterUri(
            Uri.parse('throttleiq://apexhunter/')),
        isTrue,
      );
      expect(
        HomeWidgetService.isApexHunterUri(
            Uri.parse('throttleiq://apexhunter?filter=all')),
        isTrue,
      );
    });

    test('rejects null or non-matching URIs', () {
      expect(HomeWidgetService.isApexHunterUri(null), isFalse);
      expect(
        HomeWidgetService.isApexHunterUri(Uri.parse('throttleiq://startride')),
        isFalse,
      );
      expect(
        HomeWidgetService.isApexHunterUri(Uri.parse('https://apexhunter')),
        isFalse,
      );
    });

    test('matches the advertised apexHunterUri constant', () {
      expect(
        HomeWidgetService.isApexHunterUri(HomeWidgetService.apexHunterUri),
        isTrue,
      );
    });
  });

  group('formatLeanAngle', () {
    test('formats rounded whole degrees with degree sign', () {
      expect(formatLeanAngle(0), '0°');
      expect(formatLeanAngle(24.3), '24°');
      expect(formatLeanAngle(45.6), '46°');
      expect(formatLeanAngle(55.0), '55°');
    });

    test('collapses negative, NaN, and infinite inputs to 0°', () {
      expect(formatLeanAngle(-12), '0°');
      expect(formatLeanAngle(double.nan), '0°');
      expect(formatLeanAngle(double.infinity), '0°');
      expect(formatLeanAngle(double.negativeInfinity), '0°');
    });
  });

  group('calculateLeanSymmetry', () {
    test('computes symmetry percentage accurately', () {
      expect(calculateLeanSymmetry(45, 45), '100%');
      expect(calculateLeanSymmetry(30, 40), '75%');
      expect(calculateLeanSymmetry(40, 30), '75%');
      expect(calculateLeanSymmetry(0, 0), '100%');
    });

    test('handles edge cases safely without dividing by zero or exploding', () {
      expect(calculateLeanSymmetry(0, 45), '0%');
      expect(calculateLeanSymmetry(45, 0), '0%');
      expect(calculateLeanSymmetry(-10, 45), '0%');
      expect(calculateLeanSymmetry(double.nan, 45), '0%');
      expect(calculateLeanSymmetry(double.infinity, 45), '0%');
    });
  });

  group('resolveLeanRating', () {
    test('categorizes angles by performance thresholds', () {
      expect(resolveLeanRating(15), 'STREET');
      expect(resolveLeanRating(20), 'CANYON');
      expect(resolveLeanRating(28), 'CANYON');
      expect(resolveLeanRating(32), 'SPORT');
      expect(resolveLeanRating(38), 'SPORT');
      expect(resolveLeanRating(42), 'KNEE DOWN');
      expect(resolveLeanRating(58), 'KNEE DOWN');
    });

    test('safe fallbacks for invalid inputs', () {
      expect(resolveLeanRating(-5), 'STREET');
      expect(resolveLeanRating(double.nan), 'STREET');
      expect(resolveLeanRating(double.infinity), 'STREET');
    });
  });

  group('homeWidgetServiceProvider & refreshWithData', () {
    test('homeWidgetServiceProvider provides the HomeWidgetService instance',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(homeWidgetServiceProvider),
          same(HomeWidgetService.instance));
    });

    test(
        'refreshWithData runs safely without throwing when widgets are unplaced',
        () async {
      final service = HomeWidgetService();
      await service.refreshWithData(rides: [], bikes: []);
    });

    test('publishApexHunter runs safely without throwing', () async {
      final service = HomeWidgetService();
      await service.publishApexHunter(maxLeanLeft: 38.5, maxLeanRight: 42.1);
    });
  });

  // issues §101.C9: one shared click subscription routes each widget's URI
  // to its own handler. Two separate listens on the same EventChannel meant
  // the second replaced the first, and live Start-ride taps were lost.
  group('HomeWidgetService.dispatchWidgetUri', () {
    test('each URI reaches only its own handler', () {
      var startRide = 0;
      var autoTracking = 0;
      final service = HomeWidgetService()
        ..setHandlersForTesting(
          onStartRide: () => startRide++,
          onAutoTracking: () => autoTracking++,
        );

      service.dispatchWidgetUri(Uri.parse('throttleiq://startride'));
      expect([startRide, autoTracking], [1, 0]);

      service.dispatchWidgetUri(Uri.parse('throttleiq://autotracking'));
      expect([startRide, autoTracking], [1, 1]);

      service.dispatchWidgetUri(Uri.parse('throttleiq://apexhunter'));
      service.dispatchWidgetUri(null);
      expect([startRide, autoTracking], [1, 1]);
    });

    test('no handler registered is a no-op', () {
      expect(
        () => HomeWidgetService()
            .dispatchWidgetUri(Uri.parse('throttleiq://startride')),
        returnsNormally,
      );
    });
  });

  group('widget theme payload', () {
    test('colors are #AARRGGBB, upper-case, zero-padded', () {
      expect(widgetColorHex(const Color(0xFFC8FF3D)), '#FFC8FF3D');
      expect(widgetColorHex(const Color(0x0000000A)), '#0000000A');
      expect(widgetColorHex(const Color(0xCC020A15)), '#CC020A15');
    });

    test('carries every themed role from the palette, plus brightness and mode',
        () {
      const palette = AppColorPalette.commuteLight;
      final data = widgetThemeData(palette, colorMode: AppColorMode.commute);
      expect(
          data[kWidgetKeyThemeBackground], widgetColorHex(palette.background));
      expect(data[kWidgetKeyThemeSurface], widgetColorHex(palette.surface));
      expect(data[kWidgetKeyThemeBorder], widgetColorHex(palette.border));
      expect(data[kWidgetKeyThemeInk], widgetColorHex(palette.textPrimary));
      expect(data[kWidgetKeyThemePrimary], widgetColorHex(palette.primary));
      expect(data[kWidgetKeyThemeAccent], widgetColorHex(palette.secondary));
      expect(data[kWidgetKeyThemeTextPrimary],
          widgetColorHex(palette.textPrimary));
      expect(data[kWidgetKeyThemeTextMuted],
          widgetColorHex(palette.textSecondary));
      expect(data[kWidgetKeyThemeTextTertiary],
          widgetColorHex(palette.textTertiary));
      expect(data[kWidgetKeyThemeDanger], widgetColorHex(palette.danger));
      expect(data[kWidgetKeyThemeIsDark], isFalse);
      expect(data[kWidgetKeyThemeMode], 'commute');
    });

    test(
        'on-primary matches the app\'s filled-button ink (dark on Race mustard)',
        () {
      for (final mode in AppColorMode.values) {
        for (final brightness in Brightness.values) {
          final palette = AppColorPalette.forMode(mode, brightness);
          expect(widgetThemeData(palette)[kWidgetKeyThemeOnPrimary],
              widgetColorHex(AppTheme.primaryButtonForeground(palette)),
              reason: '$mode/$brightness');
        }
      }
      expect(
          widgetThemeData(AppColorPalette.raceLight)[kWidgetKeyThemeOnPrimary],
          '#FF1A1A1A');
    });

    test('the keys match the native contract strings', () {
      // WidgetKeys.kt and ThrottleIQWidget.swift read these exact strings.
      expect(kWidgetKeyThemeBackground, 'ti_theme_background');
      expect(kWidgetKeyThemeSurface, 'ti_theme_surface');
      expect(kWidgetKeyThemeBorder, 'ti_theme_border');
      expect(kWidgetKeyThemeInk, 'ti_theme_ink');
      expect(kWidgetKeyThemePrimary, 'ti_theme_primary');
      expect(kWidgetKeyThemeOnPrimary, 'ti_theme_on_primary');
      expect(kWidgetKeyThemeAccent, 'ti_theme_accent');
      expect(kWidgetKeyThemeTextPrimary, 'ti_theme_text_primary');
      expect(kWidgetKeyThemeTextMuted, 'ti_theme_text_muted');
      expect(kWidgetKeyThemeTextTertiary, 'ti_theme_text_tertiary');
      expect(kWidgetKeyThemeDanger, 'ti_theme_danger');
      expect(kWidgetKeyThemeIsDark, 'ti_theme_is_dark');
      expect(kWidgetKeyThemeMode, 'ti_theme_mode');
    });

    test('mode is omitted when unknown', () {
      expect(
          widgetThemeData(AppColorPalette.sportDark)
              .containsKey(kWidgetKeyThemeMode),
          isFalse);
      expect(widgetThemeData(AppColorPalette.sportDark)[kWidgetKeyThemeIsDark],
          isTrue);
    });
  });

  group('HomeWidgetService.publishTheme', () {
    test('is no-op safe with no platform plugin, and remembers the theme',
        () async {
      final service = HomeWidgetService();
      await service.publishTheme(AppColorPalette.rainDark,
          colorMode: AppColorMode.rain);
      expect(
          service.publishedThemeData,
          widgetThemeData(AppColorPalette.rainDark,
              colorMode: AppColorMode.rain));
    });
  });

  group('homeWidgetThemeSyncProvider', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('publishes the active palette now and on every appearance change',
        () async {
      SharedPreferences.setMockInitialValues({});
      final fake = _RecordingWidgetService();
      final container = ProviderContainer(overrides: [
        homeWidgetServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      container.read(homeWidgetThemeSyncProvider);
      await pumpEventQueue();
      const initial = AppAppearance.defaultAppearance;
      expect(fake.published.last.$2, initial.colorMode);
      expect(fake.published.last.$1,
          same(AppColorPalette.forMode(initial.colorMode, initial.brightness)));

      await container
          .read(appearanceProvider.notifier)
          .setColorMode(AppColorMode.race);
      expect(fake.published.last.$1, same(AppColorPalette.raceLight));
      expect(fake.published.last.$2, AppColorMode.race);

      await container
          .read(appearanceProvider.notifier)
          .setBrightnessMode(AppBrightnessMode.dark);
      expect(fake.published.last.$1, same(AppColorPalette.raceDark));
    });
  });
}

class _RecordingWidgetService extends HomeWidgetService {
  final published = <(AppColorPalette, AppColorMode?)>[];

  @override
  Future<void> publishTheme(AppColorPalette palette,
      {AppColorMode? colorMode}) async {
    published.add((palette, colorMode));
  }
}
