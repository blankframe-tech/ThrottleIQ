import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../maintenance/domain/calculators/maintenance_forecast.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/domain/entities/maintenance_profile.dart';
import '../../../maintenance/presentation/maintenance_l10n.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart';
import '../../../maintenance/presentation/widgets/paperwork_card.dart';
import '../../../maintenance/presentation/widgets/quick_service_sheet.dart';

/// Simple Home's one alert, most urgent first: overdue service, expired
/// paper, paper expiring within [PaperworkEntity.warnDays], service due
/// soon. Nothing when all is fine.
class SimpleHomeAlert extends ConsumerWidget {
  final BikeEntity bike;

  /// Places module on: offer [Find mechanic] (the Bike tab's Find nearby).
  final bool places;
  const SimpleHomeAlert({super.key, required this.bike, required this.places});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // Same filter as UpNextCard.
    final items = ref.watch(maintenanceForecastProvider(bike.id)).where((f) =>
        !f.serviceType.isLowStakes && f.status != ReminderStatus.unknown);
    CheckForecast? first(ReminderStatus s) =>
        items.where((f) => f.status == s).firstOrNull;
    final papers = [...?ref.watch(paperworkProvider(bike.id)).valueOrNull]
      ..sort((a, b) => a.daysLeft(now).compareTo(b.daysLeft(now)));
    // Sorted, so an expired paper comes before an expiring one.
    final paper = papers
        .where((p) => p.daysLeft(now) <= PaperworkEntity.warnDays)
        .firstOrNull;

    final overdue = first(ReminderStatus.overdue);
    if (overdue != null) return _maintenance(context, overdue, now);
    if (paper != null) return _paper(context, paper, now);
    final soon = first(ReminderStatus.dueSoon);
    if (soon != null) return _maintenance(context, soon, now);
    return const SizedBox.shrink();
  }

  Widget _maintenance(BuildContext context, CheckForecast f, DateTime now) {
    final l10n = context.l10n;
    final label = forecastLabel(f, l10n);
    final when = dueWhenText(f, l10n, now);
    return _Card(
      overdue: f.status == ReminderStatus.overdue,
      icon: Icons.build_outlined,
      text: when.isEmpty ? label : '$label · $when',
      actions: [
        if (places)
          OutlinedButton.icon(
            key: const Key('simple_home_find_mechanic'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => context.go('/home/simple-bike'),
            icon: const Icon(Icons.place_outlined),
            label: Text(l10n.simpleHomeFindMechanic),
          ),
        FilledButton.icon(
          key: const Key('simple_home_done'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          // The same call UpNextCard's Done makes.
          onPressed: () => QuickServiceSheet.show(
            context,
            bike: bike,
            initialForecast: f,
            initialTitle: label,
            initialServiceType: f.serviceType,
          ),
          icon: const Icon(Icons.check),
          label: Text(l10n.doneIt),
        ),
      ],
    );
  }

  Widget _paper(BuildContext context, PaperworkEntity p, DateTime now) {
    final l10n = context.l10n;
    final days = p.daysLeft(now);
    final date = longDate(context, p.expiresOn);
    return _Card(
      overdue: days < 0,
      icon: Icons.description_outlined,
      text: '${paperworkLabel(p.kind, l10n)} · '
          '${days < 0 ? l10n.paperworkExpiredOn(date) : l10n.paperworkExpiresOn(date, days)}',
      actions: [
        FilledButton.icon(
          key: const Key('simple_home_renew'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () =>
              PaperworkSheet.show(context, bikeId: bike.id, existing: p),
          icon: const Icon(Icons.event_repeat),
          label: Text(l10n.simpleHomeRenew),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final bool overdue;
  final IconData icon;
  final String text;
  final List<Widget> actions;
  const _Card({
    required this.overdue,
    required this.icon,
    required this.text,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final accent = overdue ? context.palette.danger : context.palette.attention;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EditorialCard(
        key: const Key('simple_home_alert'),
        borderColor: accent,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}
