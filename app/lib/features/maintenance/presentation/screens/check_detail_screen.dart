import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/edit_maintenance_check_sheet.dart';
import '../widgets/forecast_text.dart';
import '../widgets/maintenance_check_row.dart';
import '../widgets/maintenance_format.dart';
import '../widgets/order_part_sheet.dart';

/// One tracked check up close: its status and projected date, where the
/// interval came from and why it was adapted, its own history and what it
/// has cost, and every action on it.
class CheckDetailScreen extends ConsumerWidget {
  final String bikeId;
  final String checkKey;
  const CheckDetailScreen(
      {super.key, required this.bikeId, required this.checkKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final imperial = ref.watch(maintenanceImperialProvider);
    final configs =
        ref.watch(maintenanceConfigProvider(bikeId)).valueOrNull ?? const [];
    final config = configs.where((c) => c.key == checkKey).firstOrNull;
    final forecast = ref
        .watch(maintenanceForecastProvider(bikeId))
        .where((f) => f.key == checkKey)
        .firstOrNull;
    final logs = (ref.watch(maintenanceProvider(bikeId)).valueOrNull ?? const [])
        .where((l) => l.key == checkKey)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();

    if (config == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noChecksTrackedYet)),
      );
    }
    final label = configLabel(config, l10n);
    final color = forecast == null
        ? context.palette.textTertiary
        : statusColor(context, forecast.status);
    final priced = logs.where((l) => l.cost != null).toList();

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(label)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          Row(
            children: [
              Icon(iconForServiceType(config.serviceType), size: 28, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: display(context, 22))),
              if (forecast != null)
                EditorialPill(
                  switch (forecast.status) {
                    ReminderStatus.overdue => l10n.statusOverdue,
                    ReminderStatus.dueSoon => l10n.dueSoon,
                    ReminderStatus.ok => l10n.statusOk,
                    ReminderStatus.unknown => l10n.statusUnknown,
                  },
                  tone: switch (forecast.status) {
                    ReminderStatus.overdue => PillTone.overdue,
                    ReminderStatus.dueSoon => PillTone.dueSoon,
                    ReminderStatus.ok => PillTone.ok,
                    ReminderStatus.unknown => PillTone.neutral,
                  },
                ),
            ],
          ),
          if (!config.isEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.checkNotTracked,
                  style: TextStyle(color: context.palette.textTertiary)),
            ),
          const SizedBox(height: 14),
          if (forecast != null)
            EditorialCard(
              radius: context.shape.radiusLg,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rowRemainingText(forecast, l10n, imperial),
                      style: display(context, 18, color: color)),
                  if (forecast.dueDate != null &&
                      forecast.status != ReminderStatus.overdue) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.projectedDue(longDate(context, forecast.dueDate!),
                          dueWhenText(forecast, l10n, now)),
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                  ],
                  if (forecast.status != ReminderStatus.unknown) ...[
                    const SizedBox(height: 10),
                    EditorialProgress(forecast.progress.clamp(0.0, 1.0),
                        color: color, height: 6),
                  ],
                  if (forecast.lastServiceDate != null ||
                      forecast.lastServiceKm != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      (forecast.fromBaseline
                              ? l10n.countingFromBaseline
                              : l10n.lastServicedLabel) +
                          [
                            if (forecast.lastServiceDate != null)
                              longDate(context, forecast.lastServiceDate!),
                            if (forecast.lastServiceKm != null)
                              distLabelLong(forecast.lastServiceKm!, imperial),
                          ].join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 18),

          EditorialLabel(l10n.intervalSection),
          const SizedBox(height: 8),
          EditorialCard(
            radius: context.shape.radiusLg,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (config.intervalKm > 0)
                      l10n.intervalEvery(distLabelLong(config.intervalKm, imperial)),
                    if (config.intervalDays != null)
                      l10n.everyNDays(config.intervalDays!),
                  ].join(l10n.orJoiner),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  config.source == IntervalSource.user
                      ? l10n.intervalSourceUser
                      : l10n.intervalSourceTemplate,
                  style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
                ),
                if (forecast != null && forecast.isAdapted) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.adaptedTo(distLabelLong(forecast.kmLimit, imperial)),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary),
                  ),
                  for (final r in forecast.reasons)
                    Text('· ${adaptReasonLabel(r, l10n)}',
                        style: TextStyle(
                            fontSize: 12, color: context.palette.textSecondary)),
                ],
                if ((config.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(config.notes!,
                      style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_task, size: 18),
                label: Text(l10n.logItNow),
                onPressed: () => context.push(
                    '/home/maintenance/add?bikeId=$bikeId&serviceType=${Uri.encodeComponent(checkKey)}'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.editInterval),
                onPressed: () =>
                    EditMaintenanceCheckSheet.show(context, config: config),
              ),
              if (logs.isEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(l10n.setLastDone),
                  onPressed: () => SetLastDoneSheet.show(context,
                      bikeId: bikeId, checkKey: checkKey, label: label),
                ),
              if (ref.watch(canOrderPartsProvider) &&
                  isOrderable(config.serviceType))
                OutlinedButton.icon(
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: Text(l10n.partOrderButton),
                  onPressed: () =>
                      OrderPartSheet.show(context, config.serviceType),
                ),
              if (config.isCustom)
                TextButton.icon(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: context.palette.danger),
                  label: Text(l10n.removeCheck,
                      style: TextStyle(color: context.palette.danger)),
                  onPressed: () async {
                    await ref
                        .read(maintenanceConfigProvider(bikeId).notifier)
                        .removeCustomCheck(checkKey);
                    if (context.mounted) context.pop();
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),

          EditorialLabel(l10n.itemHistory),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            Text(l10n.noPreviousServiceRecorded,
                style: TextStyle(color: context.palette.textTertiary))
          else
            EditorialCard(
              radius: context.shape.radiusLg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final l in logs)
                    ListTile(
                      dense: true,
                      title: Text(longDate(context, l.date)),
                      subtitle: Text([
                        distLabelLong(l.odometerKm, imperial),
                        if ((l.partBrand ?? '').isNotEmpty) l.partBrand!,
                        if ((l.shopName ?? '').isNotEmpty) l.shopName!,
                      ].join(' · ')),
                      trailing: l.cost != null
                          ? Text('৳${formatTaka(l.cost!)}',
                              style: const TextStyle(fontWeight: FontWeight.w700))
                          : null,
                      onTap: () => context.push(
                          '/home/maintenance/add?bikeId=$bikeId&visitId=${Uri.encodeComponent(l.visitKey)}'),
                    ),
                ],
              ),
            ),
          if (priced.length >= 2) ...[
            const SizedBox(height: 10),
            Text(
              l10n.costTrend(
                '৳${formatTaka(priced.last.cost!)}',
                '৳${formatTaka(priced.first.cost!)}',
                '৳${formatTaka(priced.map((l) => l.cost!).reduce((a, b) => a + b) / priced.length)}',
              ),
              style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
