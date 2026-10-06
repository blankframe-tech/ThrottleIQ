import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/database/daos/maintenance_profile_dao.dart';
import '../../../../core/i18n/l10n_lookup.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../garage/data/models/bike_model.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../../presentation/maintenance_l10n.dart';
import '../repositories/maintenance_forecast_repository.dart';

/// Maintenance reminders outside the app (proposal §"Reach the rider outside
/// the app"). Before this there were none at all — the only nudge was the
/// home-screen widget, which used its own thresholds.
///
/// [evaluate] runs the same forecast as the page for every bike and:
///
/// 1. **Alerts now** for any check that is due soon or overdue, once per
///    item per status per service — a rider who rode past their oil interval
///    on the way home gets "Oil change is overdue" after the ride, and not
///    again until the next oil change resets it.
/// 2. **Schedules** the date-driven ones (brake fluid age, a parked bike's
///    oil, paperwork expiry) for the day they enter their warning window, so
///    they arrive even if the app is never opened.
///
/// Called after every maintenance change, after a ride is saved, on cold
/// start and whenever the app returns to the foreground — debounced, since
/// those cluster. Low-stakes items (fuel) and unknown items never alert.
class MaintenanceAlerts {
  MaintenanceAlerts._();
  static final MaintenanceAlerts instance = MaintenanceAlerts._();

  static const prefsEnabled = 'maintenance_alerts_enabled';
  static const _prefsAlerted = 'maintenance_alerted_keys';
  static const _prefsScheduled = 'maintenance_scheduled_ids';
  static const _prefsSeeded = 'maintenance_alerts_seeded_';

  /// iOS keeps at most 64 pending notifications per app, shared with
  /// everything else ThrottleIQ schedules.
  static const _maxScheduled = 12;

  Timer? _debounce;
  var _running = false;

  /// Coalesces bursts (a visit saves several rows, a ride end invalidates
  /// several providers) into one evaluation. Inert under `flutter test`:
  /// a pending timer fails widget tests, and there is no platform to notify.
  void scheduleEvaluate({Duration delay = const Duration(seconds: 3)}) {
    if (_inTests) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(evaluate()));
  }

  static bool get _inTests {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } on UnsupportedError {
      // dart:io Platform isn't available (web).
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsEnabled) ?? true;
  }

  Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabled, on);
    if (on) {
      await evaluate();
    } else {
      await _cancelScheduled(prefs);
    }
  }

  Future<void> evaluate({DateTime? now}) async {
    if (_running) return;
    _running = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      if (uid == null) {
        // Signed out: the previous rider's scheduled reminders must not
        // fire for whoever signs in next on this phone.
        await _cancelScheduled(prefs);
        return;
      }
      if (!(prefs.getBool(prefsEnabled) ?? true)) return;

      // First run after upgrading to the redesign: existing checks just
      // gained time limits, so many would turn "overdue" at once. Record
      // them as already alerted instead of firing a burst — the page shows
      // them. Only changes from here on notify.
      final seededKey = '$_prefsSeeded$uid';
      final quiet = prefs.getBool(seededKey) != true;
      final ids = _IdAllocator.load(prefs);
      final toShow = <_Pending>[];

      final at = now ?? DateTime.now();
      final l10n = await savedL10n();
      final bikes = (await BikeDao().getAllForUser(uid))
          .map(BikeModel.fromMap)
          .toList();
      final repo = MaintenanceForecastRepository();
      final profileDao = MaintenanceProfileDao();

      final alerted = (prefs.getStringList(_prefsAlerted) ?? []).toSet();
      final stillRelevant = <String>{};
      final toSchedule = <_Pending>[];

      for (final bike in bikes) {
        final forecasts = await repo.forecastFor(bike, now: at);
        for (final f in forecasts) {
          if (f.serviceType.isLowStakes ||
              f.status == ReminderStatus.unknown) {
            continue;
          }
          final label = forecastLabel(f, l10n);
          if (f.needsAttention) {
            final key = alertKey(bike.id, f);
            stillRelevant.add(key);
            if (!alerted.contains(key)) {
              alerted.add(key);
              toShow.add(_Pending(
                at: at,
                id: ids.idFor('${bike.id}|${f.key}'),
                title: f.status == ReminderStatus.overdue
                    ? l10n.maintAlertOverdue(label)
                    : l10n.maintAlertDueSoon(label),
                body: '${remainingText(f, l10n, at)} · ${bike.displayName}',
                bikeId: bike.id,
              ));
            }
          } else {
            final when = warningStart(f, at);
            if (when != null && when.isAfter(at)) {
              toSchedule.add(_Pending(
                at: when,
                id: ids.idFor('${bike.id}|${f.key}'),
                title: l10n.maintAlertDueSoon(label),
                body: bike.displayName,
                bikeId: bike.id,
              ));
            }
          }
        }

        final papers = (await profileDao.getPaperwork(bike.id))
            .map(PaperworkEntity.fromMap)
            .whereType<PaperworkEntity>();
        for (final p in papers) {
          final days = p.daysLeft(at);
          final name = paperworkLabel(p.kind, l10n);
          final pid = ids.idFor('${bike.id}|paper:${p.kind.name}');
          if (days <= PaperworkEntity.warnDays) {
            final key = '${bike.id}|paper:${p.kind.name}|'
                '${p.expiresOn.toIso8601String().substring(0, 10)}|'
                '${days < 0 ? 'expired' : 'soon'}';
            stillRelevant.add(key);
            if (!alerted.contains(key)) {
              alerted.add(key);
              toShow.add(_Pending(
                at: at,
                id: pid,
                title: days < 0
                    ? l10n.paperworkAlertExpired(name)
                    : l10n.paperworkAlertExpiring(name, days),
                body: bike.displayName,
                bikeId: bike.id,
              ));
            }
          } else {
            toSchedule.add(_Pending(
              at: _morningOf(p.expiresOn
                  .subtract(const Duration(days: PaperworkEntity.warnDays))),
              id: pid,
              title: l10n.paperworkAlertExpiring(name, PaperworkEntity.warnDays),
              body: bike.displayName,
              bikeId: bike.id,
            ));
          }
        }
      }

      // Forget alerts whose condition has cleared (the item was serviced),
      // so the same item can alert again next cycle.
      await prefs.setStringList(
          _prefsAlerted, alerted.intersection(stillRelevant).toList());

      // Clear last run's schedule BEFORE showing anything: an item keeps
      // one id whether scheduled or shown, and cancelling an id also removes
      // a notification already on screen.
      await _cancelScheduled(prefs);
      if (!quiet) {
        for (final p in toShow) {
          await NotificationService.instance.showMaintenanceAlert(
            id: p.id,
            title: p.title,
            body: p.body,
            bikeId: p.bikeId,
          );
        }
      }
      await prefs.setBool(seededKey, true);
      await ids.save(prefs);

      toSchedule.sort((a, b) => a.at.compareTo(b.at));
      final scheduled = <String>[];
      for (final p in toSchedule.take(_maxScheduled)) {
        await NotificationService.instance.scheduleMaintenanceAlert(
          id: p.id,
          at: p.at,
          title: p.title,
          body: p.body,
          bikeId: p.bikeId,
        );
        scheduled.add('${p.id}');
      }
      await prefs.setStringList(_prefsScheduled, scheduled);
    } catch (e) {
      // Reminders are best-effort: never let one break a save or a resume.
      debugPrint('[maintenance-alerts] evaluate failed: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _cancelScheduled(SharedPreferences prefs) async {
    for (final id in prefs.getStringList(_prefsScheduled) ?? const []) {
      final n = int.tryParse(id);
      if (n != null) await NotificationService.instance.cancel(n);
    }
    await prefs.setStringList(_prefsScheduled, const []);
  }

  /// One alert per item, per status, per service: the anchor is the last
  /// service (or baseline), so logging the service re-arms it.
  @visibleForTesting
  static String alertKey(String bikeId, CheckForecast f) {
    final anchor = f.lastServiceKm?.toStringAsFixed(0) ??
        f.lastServiceDate?.toIso8601String().substring(0, 10) ??
        'none';
    return '$bikeId|${f.key}|${f.status.name}|$anchor';
  }

  /// Preferred id within the maintenance range for [key] — where the
  /// allocator starts probing.
  @visibleForTesting
  static int notificationIdFor(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return NotificationService.maintenanceIdBase +
        h % NotificationService.maintenanceIdSpan;
  }

  /// When a date-driven check enters its warning window (10:00 that day), or
  /// null when it can't be dated by the calendar alone.
  @visibleForTesting
  static DateTime? warningStart(CheckForecast f, DateTime now) {
    if (f.daysLeft == null || f.daysLimit == null) return null;
    final timeDue = now.add(Duration(days: f.daysLeft!));
    final warn = f.warnDays ?? 0;
    return _morningOf(timeDue.subtract(Duration(days: warn)));
  }

  static DateTime _morningOf(DateTime d) => DateTime(d.year, d.month, d.day, 10);
}

/// One notification id per item, kept for good. Hashing alone put ~40 keys
/// (three bikes) into 800 slots with a ~60% chance of two items sharing an
/// id — one item's alert then replaced or cancelled the other's.
@visibleForTesting
class IdAllocatorForTesting {
  static Map<String, int> allocate(Map<String, int> existing, List<String> keys) {
    final a = _IdAllocator(Map.of(existing));
    for (final k in keys) {
      a.idFor(k);
    }
    return a._ids;
  }
}

class _IdAllocator {
  _IdAllocator(this._ids);
  final Map<String, int> _ids;
  static const _prefsKey = 'maintenance_alert_ids';

  static _IdAllocator load(SharedPreferences prefs) {
    final out = <String, int>{};
    for (final entry in prefs.getStringList(_prefsKey) ?? const <String>[]) {
      final i = entry.lastIndexOf('=');
      final id = i > 0 ? int.tryParse(entry.substring(i + 1)) : null;
      if (id != null) out[entry.substring(0, i)] = id;
    }
    return _IdAllocator(out);
  }

  int idFor(String key) {
    final known = _ids[key];
    if (known != null) return known;
    final used = _ids.values.toSet();
    const base = NotificationService.maintenanceIdBase;
    const span = NotificationService.maintenanceIdSpan;
    var id = MaintenanceAlerts.notificationIdFor(key);
    for (var i = 0; i < span && used.contains(id); i++) {
      id = base + (id - base + 1) % span;
    }
    _ids[key] = id;
    return id;
  }

  Future<void> save(SharedPreferences prefs) => prefs.setStringList(
      _prefsKey, [for (final e in _ids.entries) '${e.key}=${e.value}']);
}

class _Pending {
  final DateTime at;
  final int id;
  final String title;
  final String body;
  final String bikeId;
  const _Pending({
    required this.at,
    required this.id,
    required this.title,
    required this.body,
    required this.bikeId,
  });
}

/// Notification body text for how much is left (or how far over).
String remainingText(CheckForecast f, AppLocalizations l10n, DateTime now) {
  String km(double v) => '${v.abs().toStringAsFixed(0)} km';
  if (f.status == ReminderStatus.overdue) {
    if (f.kmLeft != null && f.kmLeft! <= 0) return l10n.maintOverKm(km(f.kmLeft!));
    if (f.daysLeft != null && f.daysLeft! < 0) {
      return l10n.maintOverDays(-f.daysLeft!);
    }
  }
  if (f.daysLeft == 0) return l10n.maintDueToday;
  if (f.kmLeft != null && f.daysLeft != null) {
    return l10n.maintLeftKmOrDays(km(f.kmLeft!), f.daysLeft!);
  }
  if (f.kmLeft != null) return l10n.maintLeftKm(km(f.kmLeft!));
  if (f.daysLeft != null) return l10n.maintLeftDays(f.daysLeft!);
  return '';
}
