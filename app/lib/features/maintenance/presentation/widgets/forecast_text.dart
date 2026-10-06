import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import 'maintenance_format.dart';

/// "23 Oct" in the app language.
String shortDate(BuildContext context, DateTime d) =>
    DateFormat.MMMd(Localizations.localeOf(context).toString()).format(d);

/// "23 Oct 2026".
String longDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);

/// When it's due, in words: "in ~6 days", "tomorrow", "today", "overdue".
/// Empty when it can't be dated (no riding pace, no time limit).
String dueWhenText(CheckForecast f, AppLocalizations l10n, DateTime now) {
  if (f.status == ReminderStatus.overdue) return l10n.dueOverdue;
  final days = f.daysUntilDue(now);
  if (days == null) return '';
  if (days <= 0) return l10n.dueToday;
  if (days == 1) return l10n.dueTomorrow;
  return l10n.dueInDays(days);
}

/// What's left, in the rider's units: "1,240 km or 34 days left",
/// "120 km over", "Set last done".
String rowRemainingText(
    CheckForecast f, AppLocalizations l10n, bool imperial) {
  if (f.status == ReminderStatus.unknown) return l10n.maintUnknownStatus;
  final km = f.kmLeft;
  final days = f.daysLeft;
  if (f.status == ReminderStatus.overdue) {
    if (km != null && km <= 0) return l10n.rowOverBy(distLabelLong(-km, imperial));
    if (days != null && days < 0) return l10n.rowOverDays(-days);
  }
  if (days == 0) return l10n.maintDueToday;
  if (km != null && days != null) {
    return l10n.rowLeftKmOrDays(distLabelLong(km, imperial), days);
  }
  if (km != null) return l10n.rowLeftKm(distLabelLong(km, imperial));
  if (days != null) return l10n.rowLeftDays(days);
  return '';
}

/// The hero's second line: "410 km or 23 Oct, whichever first".
String limitsText(BuildContext context, CheckForecast f, AppLocalizations l10n,
    bool imperial, DateTime now) {
  final km = f.kmLeft;
  final days = f.daysLeft;
  final timeDue = days == null ? null : now.add(Duration(days: days));
  if (f.status == ReminderStatus.overdue) {
    return rowRemainingText(f, l10n, imperial);
  }
  if (km != null && timeDue != null) {
    return l10n.limitsKmOrDate(
        distLabelLong(km, imperial), shortDate(context, timeDue));
  }
  if (km != null) return l10n.rowLeftKm(distLabelLong(km, imperial));
  if (timeDue != null) return l10n.limitsByDate(shortDate(context, timeDue));
  return '';
}

/// Status colour, used only for meaning: red overdue, amber due soon,
/// neutral otherwise.
Color statusColor(BuildContext context, ReminderStatus s) => switch (s) {
      ReminderStatus.overdue => context.palette.danger,
      ReminderStatus.dueSoon => context.palette.attention,
      ReminderStatus.ok => context.palette.success,
      ReminderStatus.unknown => context.palette.textTertiary,
    };
