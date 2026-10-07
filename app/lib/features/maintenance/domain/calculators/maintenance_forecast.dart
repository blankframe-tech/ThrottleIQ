/// The one maintenance engine: what each tracked check needs, and when.
///
/// Before this, the page, the home-screen widget and the docs each had their
/// own idea of "due" (the widget used a separate 6-type km table and ignored
/// the rider's settings — issues §94.1). Everything now reads [forecastChecks]:
/// the maintenance page, part detail, bike detail, the widget, and
/// notifications.
///
/// For each enabled check:
///
/// 1. **Baseline** — the last log of that check; else the rider's "last
///    done" ([MaintenanceConfigEntity.baselineKm]/[baselineDate]); else the
///    caller's [ForecastInput.fallbackBaseline] (a bike added near 0 km counts
///    from when it was added). Nothing at all → [ReminderStatus.unknown],
///    never a guessed "overdue".
/// 2. **Effective interval** — the km interval × the [ConditionProfile]
///    factor for that type (when adaptation is on). Time intervals are not
///    scaled: dust doesn't age brake fluid.
/// 3. **Due** — km *or* days, whichever comes first.
/// 4. **Projected date** — km left ÷ average daily km, so the page can say
///    "in ~6 days" instead of "73%".
///
/// Pure (no SQLite, no Riverpod, no clock) — `now` is an input.
library;

import 'dart:math' as math;

import '../entities/maintenance_entity.dart';
import 'riding_conditions.dart';

/// Which limit a check will hit first.
enum DueTrigger { km, time }

class ForecastInput {
  final double currentOdometerKm;
  final DateTime now;

  /// Recent km per day; null when there's too little riding to project from.
  final double? avgDailyKm;
  final ConditionProfile conditions;

  /// The rider's "adapt intervals to my riding" switch.
  final bool adapt;

  /// Where a never-logged, no-baseline check counts from, or null when that
  /// is unknown (the bike already had km on it when it was added).
  final ({double km, DateTime date})? fallbackBaseline;

  const ForecastInput({
    required this.currentOdometerKm,
    required this.now,
    this.avgDailyKm,
    this.conditions = ConditionProfile.none,
    this.adapt = true,
    this.fallbackBaseline,
  });
}

class CheckForecast {
  final String key;
  final ServiceType serviceType;
  final String? customLabel;
  final ReminderStatus status;

  /// Distance since the last service; null when there's no km baseline.
  final double? kmSince;

  /// Effective km limit (after condition adjustment). 0 = no km trigger.
  final double kmLimit;

  /// The configured km interval before adjustment.
  final double baseKmLimit;
  final int? daysLimit;
  final double? kmLeft;
  final int? daysLeft;

  /// When it will (or did) fall due; null when neither limit can be dated.
  final DateTime? dueDate;
  final DueTrigger? trigger;
  final DateTime? lastServiceDate;
  final double? lastServiceKm;

  /// Counting from a baseline (setup / "set last done" / bike added) rather
  /// than a logged service.
  final bool fromBaseline;
  final String? notes;
  final List<AdaptReason> reasons;
  final double warnKm;
  final int? warnDays;

  const CheckForecast({
    required this.key,
    required this.serviceType,
    this.customLabel,
    required this.status,
    this.kmSince,
    required this.kmLimit,
    required this.baseKmLimit,
    this.daysLimit,
    this.kmLeft,
    this.daysLeft,
    this.dueDate,
    this.trigger,
    this.lastServiceDate,
    this.lastServiceKm,
    this.fromBaseline = false,
    this.notes,
    this.reasons = const [],
    this.warnKm = 0,
    this.warnDays,
  });

  bool get isAdapted => kmLimit > 0 && kmLimit < baseKmLimit;

  bool get needsAttention =>
      status == ReminderStatus.overdue || status == ReminderStatus.dueSoon;

  /// How used-up the item is, 0–1+, by whichever limit is closer.
  double get progress {
    var p = 0.0;
    if (kmSince != null && kmLimit > 0) {
      p = math.max(0.0, kmSince! / kmLimit);
    }
    if (daysLimit != null && daysLimit! > 0 && daysLeft != null) {
      p = math.max(p, (daysLimit! - daysLeft!) / daysLimit!);
    }
    return p;
  }

  /// Days from [now] to [dueDate] (negative when past).
  int? daysUntilDue(DateTime now) =>
      dueDate == null ? null : _dayDiff(now, dueDate!);
}

/// Default advance warning in km: 20% of a long interval, the last 150 km of
/// a short one (a 600 km chain-lube interval goes amber at 450, not 480) —
/// issues §32.
double defaultWarnKm(double kmLimit) =>
    kmLimit > 1000 ? kmLimit * 0.2 : math.min(150, kmLimit);

/// Default advance warning in days: 15% of the interval, 3–30 days.
int? defaultWarnDays(int? days) =>
    days == null ? null : (days * 0.15).round().clamp(3, 30);

/// Whole calendar days from [a] to [b] (negative when [b] is earlier).
int _dayDiff(DateTime a, DateTime b) {
  final da = DateTime(a.year, a.month, a.day);
  final db = DateTime(b.year, b.month, b.day);
  return (db.difference(da).inHours / 24).round();
}

/// The latest log for [key]: latest date, then highest odometer.
MaintenanceEntity? latestLogFor(String key, List<MaintenanceEntity> logs) {
  MaintenanceEntity? best;
  for (final l in logs) {
    if (l.key != key) continue;
    if (best == null ||
        l.date.isAfter(best.date) ||
        (l.date.isAtSameMomentAs(best.date) && l.odometerKm > best.odometerKm)) {
      best = l;
    }
  }
  return best;
}

CheckForecast forecastOne(
  MaintenanceConfigEntity config,
  List<MaintenanceEntity> logs,
  ForecastInput input,
) {
  final last = latestLogFor(config.key, logs);

  double? baseKm;
  DateTime? baseDate;
  var fromBaseline = false;
  if (last != null) {
    baseKm = last.odometerKm;
    baseDate = last.date;
  } else if (config.hasBaseline) {
    baseKm = config.baselineKm;
    baseDate = config.baselineDate;
    fromBaseline = true;
  } else if (input.fallbackBaseline != null) {
    baseKm = input.fallbackBaseline!.km;
    baseDate = input.fallbackBaseline!.date;
    fromBaseline = true;
  }

  final reasons = input.adapt
      ? input.conditions.reasonsFor(config.serviceType)
      : const <AdaptReason>[];
  final factor =
      input.adapt ? input.conditions.factorFor(config.serviceType) : 1.0;
  final kmLimit = config.intervalKm > 0 ? config.intervalKm * factor : 0.0;
  final daysLimit =
      (config.intervalDays != null && config.intervalDays! > 0)
          ? config.intervalDays
          : null;
  final warnKm = config.warnKm ?? defaultWarnKm(kmLimit);
  final warnDays = config.warnDays ?? defaultWarnDays(daysLimit);

  double? kmSince;
  double? kmLeft;
  if (baseKm != null) {
    kmSince = (input.currentOdometerKm - baseKm).toDouble();
    if (kmLimit > 0) kmLeft = kmLimit - kmSince;
  }
  int? daysLeft;
  DateTime? timeDue;
  if (baseDate != null && daysLimit != null) {
    timeDue = DateTime(baseDate.year, baseDate.month, baseDate.day + daysLimit);
    daysLeft = _dayDiff(input.now, timeDue);
  }

  if (kmLeft == null && daysLeft == null) {
    return CheckForecast(
      key: config.key,
      serviceType: config.serviceType,
      customLabel: config.customLabel,
      status: ReminderStatus.unknown,
      kmLimit: kmLimit,
      baseKmLimit: config.intervalKm,
      daysLimit: daysLimit,
      notes: config.notes,
      reasons: reasons,
      warnKm: warnKm,
      warnDays: warnDays,
    );
  }

  DateTime? kmDue;
  final avg = input.avgDailyKm;
  if (kmLeft != null && avg != null && avg >= 1) {
    kmDue = input.now.add(Duration(hours: (kmLeft / avg * 24).round()));
  }

  DateTime? dueDate;
  DueTrigger? trigger;
  if (kmDue != null && timeDue != null) {
    final kmFirst = !kmDue.isAfter(timeDue);
    dueDate = kmFirst ? kmDue : timeDue;
    trigger = kmFirst ? DueTrigger.km : DueTrigger.time;
  } else if (kmDue != null) {
    dueDate = kmDue;
    trigger = DueTrigger.km;
  } else if (timeDue != null) {
    // km can't be dated (no riding pace yet): the km limit still counts for
    // status below, the date shown is the time limit's.
    dueDate = timeDue;
    trigger = (kmLeft != null && kmLeft <= 0) ? DueTrigger.km : DueTrigger.time;
  } else {
    trigger = DueTrigger.km;
  }

  // The due day itself is "due today" (due soon), not overdue.
  final overdue =
      (kmLeft != null && kmLeft <= 0) || (daysLeft != null && daysLeft < 0);
  final dueSoon = (kmLeft != null && kmLeft <= warnKm) ||
      (daysLeft != null && warnDays != null && daysLeft <= warnDays);
  final status = overdue
      ? ReminderStatus.overdue
      : (dueSoon ? ReminderStatus.dueSoon : ReminderStatus.ok);

  return CheckForecast(
    key: config.key,
    serviceType: config.serviceType,
    customLabel: config.customLabel,
    status: status,
    kmSince: kmSince,
    kmLimit: kmLimit,
    baseKmLimit: config.intervalKm,
    daysLimit: daysLimit,
    kmLeft: kmLeft,
    daysLeft: daysLeft,
    dueDate: dueDate,
    trigger: trigger,
    lastServiceDate: last?.date ?? (fromBaseline ? baseDate : null),
    lastServiceKm: last?.odometerKm ?? (fromBaseline ? baseKm : null),
    fromBaseline: fromBaseline,
    notes: config.notes,
    reasons: reasons,
    warnKm: warnKm,
    warnDays: warnDays,
  );
}

/// Forecasts every enabled check, most urgent first: overdue (most used-up
/// first), then due soon and OK by due date, then unknown.
List<CheckForecast> forecastChecks({
  required List<MaintenanceConfigEntity> configs,
  required List<MaintenanceEntity> logs,
  required ForecastInput input,
}) {
  final out = [
    for (final c in configs)
      if (c.isEnabled) forecastOne(c, logs, input),
  ];
  out.sort(compareForecasts);
  return out;
}

int compareForecasts(CheckForecast a, CheckForecast b) {
  int rank(ReminderStatus s) => switch (s) {
        ReminderStatus.overdue => 0,
        ReminderStatus.dueSoon => 1,
        ReminderStatus.ok => 2,
        ReminderStatus.unknown => 3,
      };
  final r = rank(a.status).compareTo(rank(b.status));
  if (r != 0) return r;
  if (a.status == ReminderStatus.overdue) {
    return b.progress.compareTo(a.progress);
  }
  final ad = a.dueDate, bd = b.dueDate;
  if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
  if (ad != null && bd == null) return -1;
  if (ad == null && bd != null) return 1;
  return b.progress.compareTo(a.progress);
}

/// The one item to headline: the most urgent that isn't low-stakes (fuel)
/// and isn't unknown. Null when nothing is tracked or known.
CheckForecast? upNext(List<CheckForecast> forecasts) => forecasts
    .where((f) =>
        !f.serviceType.isLowStakes && f.status != ReminderStatus.unknown)
    .firstOrNull;

/// A bike added with at most this much on the clock counts as new: its
/// never-logged checks count from the day it was added.
const double kNewBikeMaxKm = 500;

/// Where a never-logged check on this bike counts from, or null when that's
/// unknown (§94.3). [baselineOdometerKm] is the bike's stored baseline,
/// which also holds detected-trip credits ([creditedKm]); subtracting them
/// recovers what the clock read when the bike was added.
({double km, DateTime date})? newBikeBaseline({
  required double? baselineOdometerKm,
  required double creditedKm,
  required DateTime addedAt,
}) {
  final preApp = (baselineOdometerKm ?? 0) - creditedKm;
  if (preApp > kNewBikeMaxKm) return null;
  return (km: preApp < 0 ? 0.0 : preApp, date: addedAt);
}
