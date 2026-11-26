import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/domain/calculators/maintenance_forecast.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/domain/entities/maintenance_profile.dart';
import '../../../maintenance/presentation/maintenance_l10n.dart';
import '../../../maintenance/presentation/providers/fuel_provider.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart';
import '../../../maintenance/presentation/widgets/paperwork_card.dart';
import '../../../maintenance/presentation/widgets/quick_service_sheet.dart';
import '../providers/simple_bike_provider.dart';
import '../widgets/simple_bike_nearby.dart';
import '../widgets/simple_home_help_sheet.dart';
import '../widgets/simple_rides_empty_state.dart';
import '../widgets/simple_rides_format.dart';
import '../widgets/simple_section.dart';
import '../widgets/simple_settings_button.dart';
import '../widgets/simple_theme.dart';

/// Simple mode Bike tab: the maintenance checklist (what's due first, the
/// rest folded away), fuel history, Find nearby (when Places is on) and the
/// bike's papers. Everything reads and writes through the full app's
/// providers.
class SimpleBikeScreen extends ConsumerWidget {
  const SimpleBikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bike = ref.watch(simpleBikeProvider);
    final garageLoading = ref.watch(garageProvider).isLoading;
    final places = ref.watch(appModulesProvider.select((m) => m.places));

    return SimpleTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.simpleModeNavBike),
          actions: const [SimpleEmergencyButton(), SimpleSettingsButton()],
        ),
        body: bike == null
            ? garageLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    SimpleEmptyState(
                      icon: Icons.two_wheeler,
                      title: l10n.simpleBikeNoBikeTitle,
                      body: l10n.simpleBikeNoBikeBody,
                      action: l10n.simpleBikeAddBike,
                      onPressed: () => context.push('/home/profile/add'),
                    ),
                  ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _Checklist(bike: bike),
                  const SizedBox(height: 16),
                  _FuelHistory(bikeId: bike.id),
                  if (places) ...[
                    const SizedBox(height: 16),
                    const SimpleBikeNearby(),
                  ],
                  const SizedBox(height: 16),
                  _Papers(bikeId: bike.id),
                ],
              ),
      ),
    );
  }
}

/// Rows in one card, split by hairlines.
Widget _rows(BuildContext context, List<Widget> rows) => EditorialCard(
      radius: context.shape.radiusLg,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1),
            r,
          ],
        ],
      ),
    );

class _Checklist extends ConsumerWidget {
  const _Checklist({required this.bike});

  final BikeEntity bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final checks = ref
        .watch(maintenanceForecastProvider(bike.id))
        .where((f) => f.status != ReminderStatus.unknown)
        .toList();
    // The forecast is empty while its sources load; don't flash "Set up".
    final loading = ref.watch(maintenanceConfigProvider(bike.id)).isLoading ||
        ref.watch(maintenanceProvider(bike.id)).isLoading;
    final imperial = ref.watch(maintenanceImperialProvider);
    final now = DateTime.now();
    // Overdue first, then due soon; the fine ones fold away.
    final due = [
      ...checks.where((f) => f.status == ReminderStatus.overdue),
      ...checks.where((f) => f.status == ReminderStatus.dueSoon),
    ];
    final fine = checks.where((f) => f.status == ReminderStatus.ok).toList();

    Widget row(CheckForecast f) {
      final label = forecastLabel(f, l10n);
      // An undatable km-only check says the km instead.
      final when = dueWhenText(f, l10n, now);
      final (String status, Color color) = switch (f.status) {
        ReminderStatus.ok => (l10n.simpleBikeCheckOk, palette.textSecondary),
        ReminderStatus.overdue => (when, palette.danger),
        _ => (
            when.isNotEmpty ? when : rowRemainingText(f, l10n, imperial),
            palette.attention
          ),
      };
      // The same call UpNextCard makes.
      void done() => QuickServiceSheet.show(
            context,
            bike: bike,
            initialForecast: f,
            initialTitle: label,
            initialServiceType: f.serviceType,
          );
      final doneText = Text(l10n.simpleBikeCheckDone);
      return Padding(
        key: Key('simpleBikeCheck_${f.key}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  Text(status, style: TextStyle(color: color)),
                ],
              ),
            ),
            // Due: a real button. Fine: a quiet link, for early services.
            if (f.status == ReminderStatus.ok)
              TextButton(onPressed: done, child: doneText)
            else
              OutlinedButton(onPressed: done, child: doneText),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimpleSectionHeader(l10n.simpleBikeChecksTitle),
        if (checks.isEmpty && loading)
          const SizedBox.shrink()
        else if (checks.isEmpty) ...[
          Text(l10n.simpleBikeSetupBody,
              style: TextStyle(color: palette.textSecondary)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('simpleBikeSetup'),
            onPressed: () => context.push(
                '/home/maintenance/setup?bikeId=${bike.id}&firstTime=true'),
            child: Text(l10n.simpleBikeSetupAction),
          ),
        ] else
          _rows(context, [
            for (final f in due) row(f),
            if (fine.isNotEmpty)
              ExpansionTile(
                key: const Key('simpleBikeChecksFine'),
                tilePadding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                leading:
                    Icon(Icons.check_circle_outline, color: palette.success),
                title: Text(l10n.simpleBikeChecksFine(fine.length)),
                children: [
                  for (final f in fine) ...[const Divider(height: 1), row(f)],
                ],
              ),
          ]),
      ],
    );
  }
}

class _FuelHistory extends ConsumerWidget {
  const _FuelHistory({required this.bikeId});

  final String bikeId;

  // shortcut: the latest 5 fills only; the full list stays in the full app.
  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(fuelLogsProvider(bikeId));
    final logs = [...?async.valueOrNull]
      ..sort((a, b) => b.filledAt.compareTo(a.filledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimpleSectionHeader(
          l10n.simpleBikeFuelTitle,
          action: TextButton.icon(
            key: const Key('simpleBikeAddFuel'),
            onPressed: () =>
                context.push('/home/maintenance/fuel/add?bikeId=$bikeId'),
            icon: const Icon(Icons.add),
            label: Text(l10n.simpleBikeAddFuel),
          ),
        ),
        // Loading or failed is not "no fill-ups".
        if (!async.hasValue && async.hasError) ...[
          Text(mapFirestoreError(async.error!, l10n),
              key: const Key('simpleBikeFuelFailed')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('simpleBikeFuelRetry'),
            onPressed: () => ref.invalidate(fuelLogsProvider(bikeId)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ] else if (!async.hasValue)
          const Center(child: CircularProgressIndicator())
        else if (logs.isEmpty)
          Text(l10n.simpleBikeFuelEmpty,
              style: TextStyle(color: context.palette.textSecondary))
        else
          _rows(context, [
            for (final log in logs.take(_shown))
              ListTile(
                key: Key('simpleBikeFuel_${log.id}'),
                title: Text('৳${simpleAmount(log.totalCost)}',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                    '${longDate(context, log.filledAt)} · ${l10n.simpleBikeFuelLitres(log.liters.toStringAsFixed(1))}'),
              ),
          ]),
      ],
    );
  }
}

/// The bike's papers, soonest to expire first. Same data and sheet as the
/// full app's [PaperworkCard], in Simple's section style.
class _Papers extends ConsumerWidget {
  const _Papers({required this.bikeId});

  final String bikeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final now = DateTime.now();
    final papers = [...?ref.watch(paperworkProvider(bikeId)).valueOrNull]
      ..sort((a, b) => a.daysLeft(now).compareTo(b.daysLeft(now)));

    Widget paper(PaperworkEntity p) {
      final days = p.daysLeft(now);
      final date = longDate(context, p.expiresOn);
      final color = days < 0
          ? palette.danger
          : days <= PaperworkEntity.warnDays
              ? palette.attention
              : palette.textSecondary;
      return ListTile(
        key: Key('simpleBikePaper_${p.kind.name}'),
        leading: Icon(Icons.description_outlined, color: color),
        title: Text(paperworkLabel(p.kind, l10n),
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
            days < 0
                ? l10n.paperworkExpiredOn(date)
                : l10n.paperworkExpiresOn(date, days),
            style: TextStyle(color: color)),
        trailing: Icon(Icons.chevron_right, color: palette.textTertiary),
        onTap: () => PaperworkSheet.show(context, bikeId: bikeId, existing: p),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimpleSectionHeader(
          l10n.paperworkTitle,
          action: TextButton.icon(
            key: const Key('simpleBikeAddPaper'),
            onPressed: () => PaperworkSheet.show(context, bikeId: bikeId),
            icon: const Icon(Icons.add),
            label: Text(l10n.addAction),
          ),
        ),
        if (papers.isEmpty)
          Text(l10n.paperworkEmpty,
              style: TextStyle(color: palette.textSecondary))
        else
          _rows(context, [
            for (final p in papers) paper(p),
          ]),
      ],
    );
  }
}
