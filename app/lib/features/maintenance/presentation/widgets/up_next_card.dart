import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import 'edit_maintenance_check_sheet.dart' show iconForServiceType;
import 'forecast_text.dart';
import 'maintenance_format.dart';

/// "Remind me later" on the hero: hides that item from the headline for
/// [snoozeDays], keyed to its last service so logging it clears the snooze.
class HeroSnoozeNotifier extends StateNotifier<Map<String, DateTime>> {
  HeroSnoozeNotifier() : super(const {}) {
    _load();
  }

  static const _prefsKey = 'maintenance_hero_snooze';
  static const snoozeDays = 3;

  static String keyFor(String bikeId, CheckForecast f) =>
      '$bikeId|${f.key}|${f.lastServiceKm?.toStringAsFixed(0) ?? '-'}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || !mounted) return;
      final map = (jsonDecode(raw) as Map).map((k, v) =>
          MapEntry(k as String, DateTime.tryParse(v as String) ?? DateTime(0)));
      state = map;
    } catch (_) {}
  }

  Future<void> snooze(String key) async {
    final until = DateTime.now().add(const Duration(days: snoozeDays));
    final now = DateTime.now();
    state = {
      for (final e in state.entries)
        if (e.value.isAfter(now)) e.key: e.value,
      key: until,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey,
          jsonEncode(state.map((k, v) => MapEntry(k, v.toIso8601String()))));
    } catch (_) {}
  }

  bool isSnoozed(String key, DateTime now) =>
      state[key] != null && state[key]!.isAfter(now);
}

final heroSnoozeProvider =
    StateNotifierProvider<HeroSnoozeNotifier, Map<String, DateTime>>(
        (ref) => HeroSnoozeNotifier());

/// The page's answer in one second: what the bike needs next, and when.
class UpNextCard extends ConsumerWidget {
  final String bikeId;
  final bool imperial;
  const UpNextCard({super.key, required this.bikeId, required this.imperial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final forecasts = ref.watch(maintenanceForecastProvider(bikeId));
    final snoozes = ref.watch(heroSnoozeProvider.notifier);
    ref.watch(heroSnoozeProvider);
    final candidates = forecasts
        .where((f) =>
            !f.serviceType.isLowStakes &&
            f.status != ReminderStatus.unknown &&
            !snoozes.isSnoozed(HeroSnoozeNotifier.keyFor(bikeId, f), now))
        .toList();
    final f = candidates.firstOrNull;
    if (f == null) return const SizedBox.shrink();

    final calm = f.status == ReminderStatus.ok &&
        (f.daysUntilDue(now) == null || f.daysUntilDue(now)! > 14);
    final logs = ref.watch(maintenanceProvider(bikeId)).valueOrNull ?? const [];
    final last = latestLogFor(f.key, logs);
    final onInk = context.palette.onInk;
    final muted = context.palette.onInkMuted;
    final accent = switch (f.status) {
      ReminderStatus.overdue => context.palette.danger,
      ReminderStatus.dueSoon => context.palette.attention,
      _ => context.palette.primaryHighlight,
    };

    if (calm) {
      final until = f.dueDate;
      return InkPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: context.palette.success, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    until != null
                        ? l10n.allGoodUntil(shortDate(context, until))
                        : l10n.allGoodNothingDue,
                    style: display(context, 18, color: onInk),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.nextUpIs(forecastLabel(f, l10n)),
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final when = dueWhenText(f, l10n, now);
    final lastLine = last == null
        ? null
        : [
            if ((last.partBrand ?? '').isNotEmpty || (last.partGrade ?? '').isNotEmpty)
              [last.partBrand, last.partGrade]
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .join(' '),
            l10n.atOdometer(distLabelLong(last.odometerKm, imperial)),
            if (last.cost != null) '৳${formatTaka(last.cost!)}',
            if ((last.shopName ?? '').isNotEmpty) last.shopName!,
          ].join(' · ');

    return InkPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.upNext.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: muted)),
              const Spacer(),
              Icon(iconForServiceType(f.serviceType), size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            when.isEmpty
                ? forecastLabel(f, l10n)
                : '${forecastLabel(f, l10n)} · $when',
            style: display(context, 22, color: onInk),
          ),
          const SizedBox(height: 4),
          Text(
            limitsText(context, f, l10n, imperial, now),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: f.status == ReminderStatus.ok ? onInk : accent),
          ),
          if (lastLine != null) ...[
            const SizedBox(height: 4),
            Text(l10n.lastServiceLine(lastLine),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: muted)),
          ],
          if (f.reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              f.reasons.map((r) => adaptReasonLabel(r, l10n)).join(' · '),
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('heroDoneIt'),
                  onPressed: () => context.push(
                      '/home/maintenance/add?bikeId=$bikeId&serviceType=${Uri.encodeComponent(f.key)}'),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.doneIt,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(context.shape.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(heroSnoozeProvider.notifier)
                        .snooze(HeroSnoozeNotifier.keyFor(bikeId, f));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            l10n.snoozedFor(HeroSnoozeNotifier.snoozeDays))));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onInk,
                    side: BorderSide(color: muted),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(context.shape.radiusMd),
                    ),
                  ),
                  child: Text(l10n.remindMeLater),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
