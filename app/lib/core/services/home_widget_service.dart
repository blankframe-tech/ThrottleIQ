import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:home_widget/home_widget.dart';

import '../constants/sensor_constants.dart';
import '../database/daos/bike_dao.dart';
import '../database/daos/maintenance_dao.dart';
import '../database/daos/ride_dao.dart';
import '../../features/garage/data/models/bike_model.dart';
import '../../features/garage/domain/entities/bike_entity.dart';
import '../../features/maintenance/data/models/maintenance_model.dart';
import '../../features/maintenance/domain/entities/maintenance_entity.dart';
import '../../features/ride/data/models/ride_model.dart';
import '../../features/ride/domain/entities/ride_entity.dart';

// ---------------------------------------------------------------------------
// SharedPreferences / UserDefaults keys.
//
// These are the contract between Dart and the native widget code. The Android
// providers (StartRideWidgetProvider / RideStatsWidgetProvider /
// MaintenanceWidgetProvider) and the iOS WidgetKit bundle
// (ios/ThrottleIQWidget/ThrottleIQWidget.swift) read these exact strings, so
// renaming one here silently blanks a widget. Change both sides together.
//
// Every "display" key holds a fully-formatted, ready-to-render string so the
// native layouts stay dumb (no number formatting in Kotlin or Swift). The
// "_raw" twins carry the underlying numbers for anything native that later
// wants to compute (progress bars, colour thresholds, complications).
// ---------------------------------------------------------------------------

/// Ride stats widget keys.
const String kWidgetKeyWeeklyKm = 'ti_weekly_km';
const String kWidgetKeyWeeklyKmRaw = 'ti_weekly_km_raw';
const String kWidgetKeyTotalKm = 'ti_total_km';
const String kWidgetKeyTotalKmRaw = 'ti_total_km_raw';
const String kWidgetKeyRideCount = 'ti_ride_count';
const String kWidgetKeyRideCountRaw = 'ti_ride_count_raw';
const String kWidgetKeyStatsUpdatedAt = 'ti_stats_updated_at';

/// Maintenance widget keys.
const String kWidgetKeyBikeName = 'ti_bike_name';
const String kWidgetKeyServiceLabel = 'ti_service_label';
const String kWidgetKeyServiceSummary = 'ti_service_summary';
const String kWidgetKeyKmUntilDue = 'ti_km_until_due';
const String kWidgetKeyKmUntilDueRaw = 'ti_km_until_due_raw';
const String kWidgetKeyOverdue = 'ti_overdue';
const String kWidgetKeyMaintenanceUpdatedAt = 'ti_maintenance_updated_at';

/// Shown by both platforms before the app has ever published anything. Native
/// code has its own copy of these as a defensive default; keeping them here
/// means a "signed out"/"no bikes" refresh can publish them explicitly rather
/// than leaving stale numbers from a previous account on the home screen.
const String kWidgetPlaceholderValue = '—';
const String kWidgetPlaceholderNoData = 'No data yet';
const String kWidgetPlaceholderNoService = 'No service data yet';

// ---------------------------------------------------------------------------
// Pure formatting helpers.
//
// Deliberately top-level (not methods) so they are unit-testable without any
// plugin, platform channel or Firebase in play — see
// test/core/services/home_widget_service_test.dart.
// ---------------------------------------------------------------------------

/// A distance rendered for a home-screen widget: `'0 km'`, `'128.4 km'`,
/// `'12,480 km'`.
///
/// Widgets are glanceable, not precise instruments, so this trades decimals
/// for width as the number grows: one decimal below 1000 km, whole kilometres
/// with thousands separators above. Non-finite and negative inputs (a corrupt
/// row, a bad subtraction) collapse to `'0 km'` rather than rendering `NaN`
/// on someone's home screen.
String formatKm(double km) {
  if (km.isNaN || km.isInfinite) return '0 km';
  if (km < 0.05) return '0 km';
  if (km < 1000) return '${km.toStringAsFixed(1)} km';
  return '${_withThousandsSeparator(km.round())} km';
}

/// `'0 rides'` / `'1 ride'` / `'42 rides'`. Negatives clamp to zero.
String formatRideCount(int count) {
  final n = count < 0 ? 0 : count;
  return '$n ${n == 1 ? 'ride' : 'rides'}';
}

/// The one-line "what's next" sentence on the maintenance widget.
///
/// [kmUntilDue] is signed distance-to-limit as computed by
/// [computeNextService]; when [overdue] is true the caller may pass either the
/// negative remainder or its magnitude, so this normalises with `abs()` and
/// lets [overdue] — not the sign — decide the wording. `kmUntilDue <= 0`
/// without [overdue] means "at the limit but not past the hard threshold",
/// which reads as due now rather than overdue.
String formatNextServiceSummary({
  required String serviceLabel,
  required double kmUntilDue,
  required bool overdue,
}) {
  final label = serviceLabel.trim().isEmpty ? 'Service' : serviceLabel.trim();
  if (overdue) return '$label overdue by ${formatKm(kmUntilDue.abs())}';
  if (kmUntilDue.isNaN || kmUntilDue <= 0) return '$label due now';
  return '$label in ${formatKm(kmUntilDue)}';
}

String _withThousandsSeparator(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Kilometres ridden in the rolling 7 days ending at [now] (defaults to
/// wall-clock now). Rolling rather than calendar-week so the widget never
/// resets to zero mid-Monday-morning commute.
double weeklyDistanceKm(List<RideEntity> rides, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 7));
  return rides
      .where((r) => r.startTime.isAfter(cutoff))
      .fold<double>(0, (sum, r) => sum + r.distanceKm);
}

/// The single service the maintenance widget should nag about.
class NextServiceDue {
  final ServiceType serviceType;

  /// Distance left before the hard limit. Negative once past it.
  final double kmUntilDue;
  final bool overdue;

  const NextServiceDue({
    required this.serviceType,
    required this.kmUntilDue,
    required this.overdue,
  });

  String get label => serviceType.label;
}

/// Which reminder-eligible services the widget considers. Mirrors the
/// maintenance feature's own reminder list — the expanded [ServiceType] enum
/// is log-only for the rest, and a widget that nagged about valve clearance
/// would be noise.
const List<ServiceType> kWidgetReminderTypes = [
  ServiceType.oilChange,
  ServiceType.airFilter,
  ServiceType.chain,
  ServiceType.tire,
  ServiceType.brakeFluid,
  ServiceType.frontDiscPads,
];

/// Picks the most urgent service for a bike: the one with the least distance
/// left before its limit. Overdue items always beat not-yet-due ones, and
/// among several overdue items the *most* overdue wins.
///
/// Returns null only when there is nothing to say at all (no eligible types),
/// never for "no logs" — a bike with no oil change on record is exactly the
/// bike that most needs the reminder, measured from 0 km.
NextServiceDue? computeNextService({
  required double currentOdometerKm,
  required List<MaintenanceEntity> logs,
}) {
  NextServiceDue? best;
  for (final type in kWidgetReminderTypes) {
    final limitKm = _limitKmFor(type);
    if (!limitKm.isFinite) continue;

    final typeLogs = logs.where((l) => l.serviceType == type).toList()
      ..sort((a, b) => b.odometerKm.compareTo(a.odometerKm));
    final lastKm = typeLogs.isEmpty ? 0.0 : typeLogs.first.odometerKm;
    final kmSince = currentOdometerKm - lastKm;
    final kmUntilDue = limitKm - kmSince;

    final candidate = NextServiceDue(
      serviceType: type,
      kmUntilDue: kmUntilDue,
      overdue: kmSince >= limitKm,
    );
    if (best == null || candidate.kmUntilDue < best.kmUntilDue) {
      best = candidate;
    }
  }
  return best;
}

double _limitKmFor(ServiceType type) {
  switch (type) {
    case ServiceType.oilChange:
      return SensorConstants.oilChangeMaxKm;
    case ServiceType.airFilter:
      return SensorConstants.airFilterMaxKm;
    case ServiceType.chain:
      return SensorConstants.chainLubeMaxKm;
    case ServiceType.tire:
      return SensorConstants.tireCheckMaxKm;
    case ServiceType.brakeFluid:
      return SensorConstants.brakeFluidMaxKm;
    case ServiceType.frontDiscPads:
      return SensorConstants.discPadsMaxKm;
    default:
      return double.infinity;
  }
}

// ---------------------------------------------------------------------------
// The service.
// ---------------------------------------------------------------------------

/// Publishes home-screen widget data for Android App Widgets and iOS WidgetKit.
///
/// **Every public method is no-op safe.** `home_widget` throws whenever the
/// platform side isn't there — unit tests with no plugin registered, iOS
/// before the widget extension target has been added to the Xcode project,
/// Android launchers with no widget placed, desktop/web. A home-screen widget
/// failing to refresh is cosmetic; it must never take down app startup or a
/// ride save, so everything here catches, logs and returns.
class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  /// Must match the App Group added to BOTH the Runner and ThrottleIQWidget
  /// targets in Xcode (see ios/ThrottleIQWidget/README.md). Ignored on Android.
  static const String appGroupId = 'group.com.bft.throttleiq';

  /// Android provider class names (relative to `com.bft.throttleiq`) and the
  /// iOS WidgetKit `kind` strings. Both sides must match the native sources.
  static const String androidStartRideWidget = 'StartRideWidgetProvider';
  static const String androidRideStatsWidget = 'RideStatsWidgetProvider';
  static const String androidMaintenanceWidget = 'MaintenanceWidgetProvider';
  static const String iosStartRideWidget = 'ThrottleIQStartRideWidget';
  static const String iosRideStatsWidget = 'ThrottleIQRideStatsWidget';
  static const String iosMaintenanceWidget = 'ThrottleIQMaintenanceWidget';

  static const String _androidPackage = 'com.bft.throttleiq';

  bool _appGroupSet = false;

  /// Call once on app start. Safe to call again.
  Future<void> initialize() async {
    if (_appGroupSet) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _appGroupSet = true;
    } catch (e, s) {
      _log('setAppGroupId failed', e, s);
    }
  }

  /// One-shot startup entry point: initialise, then push whatever the local
  /// database already knows. Deliberately the only thing `main()` has to call.
  Future<void> bootstrap() async {
    await initialize();
    await refreshFromLocalData();
  }

  /// The URI the "Start ride" widget launches the app with.
  static final Uri startRideUri = Uri.parse('throttleiq://startride');

  /// Whether [uri] is the widget's start-ride request.
  ///
  /// Compares scheme + host rather than the whole string: Android and iOS
  /// hand the URI back with slightly different trailing-slash treatment, and
  /// a raw `==` misses one of them.
  static bool isStartRideUri(Uri? uri) =>
      uri != null && uri.scheme == 'throttleiq' && uri.host == 'startride';

  /// Fires [onStartRide] when the app is opened from the start-ride widget —
  /// both for a cold launch and for a tap while the app is already alive.
  ///
  /// Wrapped so a platform that has no widget support (or a launch with no
  /// URI at all, i.e. a normal icon tap) is a silent no-op rather than an
  /// error on every start.
  Future<void> registerStartRideHandler(VoidCallback onStartRide) async {
    try {
      final launched = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (isStartRideUri(launched)) onStartRide();

      HomeWidget.widgetClicked.listen((uri) {
        if (isStartRideUri(uri)) onStartRide();
      });
    } catch (e, s) {
      _log('registerStartRideHandler failed', e, s);
    }
  }

  Future<void> publishRideStats({
    required double weeklyKm,
    required double totalKm,
    required int rideCount,
  }) async {
    try {
      await Future.wait([
        _save(kWidgetKeyWeeklyKm, formatKm(weeklyKm)),
        _save(kWidgetKeyWeeklyKmRaw, weeklyKm),
        _save(kWidgetKeyTotalKm, formatKm(totalKm)),
        _save(kWidgetKeyTotalKmRaw, totalKm),
        _save(kWidgetKeyRideCount, formatRideCount(rideCount)),
        _save(kWidgetKeyRideCountRaw, rideCount),
        _save(kWidgetKeyStatsUpdatedAt, DateTime.now().toIso8601String()),
      ]);
      await _update(
        androidName: androidRideStatsWidget,
        iOSName: iosRideStatsWidget,
      );
    } catch (e, s) {
      _log('publishRideStats failed', e, s);
    }
  }

  Future<void> publishMaintenance({
    required String bikeName,
    required String nextServiceLabel,
    required double kmUntilDue,
    required bool overdue,
  }) async {
    try {
      final summary = formatNextServiceSummary(
        serviceLabel: nextServiceLabel,
        kmUntilDue: kmUntilDue,
        overdue: overdue,
      );
      await Future.wait([
        _save(kWidgetKeyBikeName,
            bikeName.trim().isEmpty ? kWidgetPlaceholderValue : bikeName.trim()),
        _save(kWidgetKeyServiceLabel, nextServiceLabel),
        _save(kWidgetKeyServiceSummary, summary),
        _save(kWidgetKeyKmUntilDue, formatKm(kmUntilDue.abs())),
        _save(kWidgetKeyKmUntilDueRaw, kmUntilDue),
        _save(kWidgetKeyOverdue, overdue),
        _save(kWidgetKeyMaintenanceUpdatedAt, DateTime.now().toIso8601String()),
      ]);
      await _update(
        androidName: androidMaintenanceWidget,
        iOSName: iosMaintenanceWidget,
      );
    } catch (e, s) {
      _log('publishMaintenance failed', e, s);
    }
  }

  /// Resets both data widgets to their "nothing to show" state — used when
  /// signed out or when the rider has no bikes, so a previous account's
  /// numbers don't linger on the home screen.
  Future<void> publishPlaceholders() async {
    try {
      await Future.wait([
        _save(kWidgetKeyWeeklyKm, kWidgetPlaceholderValue),
        _save(kWidgetKeyTotalKm, kWidgetPlaceholderValue),
        _save(kWidgetKeyRideCount, kWidgetPlaceholderNoData),
        _save(kWidgetKeyBikeName, kWidgetPlaceholderValue),
        _save(kWidgetKeyServiceLabel, ''),
        _save(kWidgetKeyServiceSummary, kWidgetPlaceholderNoService),
        _save(kWidgetKeyKmUntilDue, kWidgetPlaceholderValue),
        _save(kWidgetKeyOverdue, false),
      ]);
      await refreshAllWidgets();
    } catch (e, s) {
      _log('publishPlaceholders failed', e, s);
    }
  }

  /// Re-renders all three widgets from whatever is already stored.
  Future<void> refreshAllWidgets() async {
    await _update(
        androidName: androidStartRideWidget, iOSName: iosStartRideWidget);
    await _update(
        androidName: androidRideStatsWidget, iOSName: iosRideStatsWidget);
    await _update(
        androidName: androidMaintenanceWidget, iOSName: iosMaintenanceWidget);
  }

  /// Reads the offline-first local database (the same tables the Stats hub and
  /// Maintenance screen read) and republishes both data widgets.
  ///
  /// Signed out, or DB not yet created on a fresh install, publishes
  /// placeholders instead of leaving the widget blank.
  Future<void> refreshFromLocalData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        await publishPlaceholders();
        return;
      }

      final rideRows = await RideDao().getAllForUser(uid);
      final rides = rideRows.map(RideModel.fromMap).toList();
      final totalKm = rides.fold<double>(0, (sum, r) => sum + r.distanceKm);
      await publishRideStats(
        weeklyKm: weeklyDistanceKm(rides),
        totalKm: totalKm,
        rideCount: rides.length,
      );

      final bikeRows = await BikeDao().getAllForUser(uid);
      final bikes = bikeRows.map(BikeModel.fromMap).toList();
      if (bikes.isEmpty) {
        await publishMaintenanceEmpty();
        return;
      }
      final bike = _preferredBike(bikes);
      final logRows = await MaintenanceDao().getForBike(bike.id);
      final logs = logRows.map(MaintenanceModel.fromMap).toList();
      final next = computeNextService(
        currentOdometerKm: bike.currentOdometerKm,
        logs: logs,
      );
      if (next == null) {
        await publishMaintenanceEmpty();
        return;
      }
      await publishMaintenance(
        bikeName: bike.displayName,
        nextServiceLabel: next.label,
        kmUntilDue: next.kmUntilDue,
        overdue: next.overdue,
      );
    } catch (e, s) {
      _log('refreshFromLocalData failed', e, s);
    }
  }

  /// Maintenance widget with nothing to report yet.
  Future<void> publishMaintenanceEmpty() async {
    try {
      await Future.wait([
        _save(kWidgetKeyBikeName, kWidgetPlaceholderValue),
        _save(kWidgetKeyServiceLabel, ''),
        _save(kWidgetKeyServiceSummary, kWidgetPlaceholderNoService),
        _save(kWidgetKeyKmUntilDue, kWidgetPlaceholderValue),
        _save(kWidgetKeyKmUntilDueRaw, 0.0),
        _save(kWidgetKeyOverdue, false),
      ]);
      await _update(
        androidName: androidMaintenanceWidget,
        iOSName: iosMaintenanceWidget,
      );
    } catch (e, s) {
      _log('publishMaintenanceEmpty failed', e, s);
    }
  }

  /// The active bike if one is flagged, otherwise the most-ridden one — the
  /// same "which bike does the rider mean" answer the garage UI gives.
  BikeEntity _preferredBike(List<BikeEntity> bikes) {
    for (final b in bikes) {
      if (b.isActive) return b;
    }
    return bikes.reduce((a, b) => b.rideCount > a.rideCount ? b : a);
  }

  Future<void> _save(String key, Object? value) async {
    try {
      await HomeWidget.saveWidgetData(key, value);
    } catch (e, s) {
      _log('saveWidgetData($key) failed', e, s);
    }
  }

  Future<void> _update({
    required String androidName,
    required String iOSName,
  }) async {
    try {
      await HomeWidget.updateWidget(
        name: androidName,
        androidName: androidName,
        qualifiedAndroidName: '$_androidPackage.$androidName',
        iOSName: iOSName,
      );
    } catch (e, s) {
      _log('updateWidget($androidName) failed', e, s);
    }
  }

  void _log(String message, Object error, StackTrace stack) {
    developer.log(
      message,
      name: 'HomeWidgetService',
      error: error,
      stackTrace: stack,
    );
  }
}
