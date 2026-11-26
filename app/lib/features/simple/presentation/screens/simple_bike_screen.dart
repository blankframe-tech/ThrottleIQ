import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/app_modules.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/domain/calculators/maintenance_forecast.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/presentation/maintenance_l10n.dart';
import '../../../maintenance/presentation/providers/fuel_provider.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart';
import '../../../maintenance/presentation/widgets/maintenance_format.dart';
import '../../../maintenance/presentation/widgets/paperwork_card.dart';
import '../../../maintenance/presentation/widgets/quick_service_sheet.dart';
import '../providers/simple_bike_provider.dart';
import '../widgets/simple_bike_nearby.dart';
import '../widgets/simple_rides_empty_state.dart';
import '../widgets/simple_settings_button.dart';

/// Simple mode Bike tab: the maintenance checklist with Done, fuel history,
/// Find nearby (when Places is on) and the bike's papers. Everything reads
/// and writes through the full app's providers.
class SimpleBikeScreen extends ConsumerWidget {
  const SimpleBikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bike = ref.watch(simpleBikeProvider);
    final garageLoading = ref.watch(garageProvider).isLoading;
    final places = ref.watch(appModulesProvider.select((m) => m.places));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(bike?.displayName ?? l10n.simpleModeNavBike),
        actions: const [SimpleSettingsButton()],
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
              padding: const EdgeInsets.all(16),
              children: [
                _Checklist(bike: bike),
                const SizedBox(height: 24),
                _FuelHistory(bikeId: bike.id),
                if (places) ...[
                  const SizedBox(height: 24),
                  const SimpleBikeNearby(),
                ],
                const SizedBox(height: 24),
                PaperworkCard(bikeId: bike.id),
              ],
            ),
    );
  }
}

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

    String status(CheckForecast f) {
      if (f.status == ReminderStatus.ok) return l10n.simpleBikeCheckOk;
      final when = dueWhenText(f, l10n, now);
      return when.isNotEmpty ? when : rowRemainingText(f, l10n, imperial);
    }

    Color color(ReminderStatus s) => switch (s) {
          ReminderStatus.overdue => palette.danger,
          ReminderStatus.dueSoon => palette.attention,
          _ => palette.success,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialLabel(l10n.simpleBikeChecksTitle),
        const SizedBox(height: 8),
        if (checks.isEmpty && loading)
          const SizedBox.shrink()
        else if (checks.isEmpty) ...[
          Text(l10n.simpleBikeSetupBody,
              style: TextStyle(color: palette.textSecondary)),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('simpleBikeSetup'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
            onPressed: () => context.push(
                '/home/maintenance/setup?bikeId=${bike.id}&firstTime=true'),
            child: Text(l10n.simpleBikeSetupAction),
          ),
        ] else
          EditorialCard(
            radius: context.shape.radiusLg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final f in checks)
                  Padding(
                    key: Key('simpleBikeCheck_${f.key}'),
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(forecastLabel(f, l10n),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(status(f),
                                  style: TextStyle(color: color(f.status))),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48)),
                          // The same call UpNextCard makes.
                          onPressed: () => QuickServiceSheet.show(
                            context,
                            bike: bike,
                            initialForecast: f,
                            initialTitle: forecastLabel(f, l10n),
                            initialServiceType: f.serviceType,
                          ),
                          child: Text(l10n.simpleBikeCheckDone),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FuelHistory extends ConsumerWidget {
  const _FuelHistory({required this.bikeId});

  final String bikeId;

  // shortcut: the latest 10 fills only; the full list stays in the full app.
  static const _shown = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logs = [...?ref.watch(fuelLogsProvider(bikeId)).valueOrNull]
      ..sort((a, b) => b.filledAt.compareTo(a.filledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialLabel(l10n.simpleBikeFuelTitle),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          Text(l10n.simpleBikeFuelEmpty,
              style: TextStyle(color: context.palette.textTertiary))
        else
          EditorialCard(
            radius: context.shape.radiusLg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final log in logs.take(_shown))
                  ListTile(
                    key: Key('simpleBikeFuel_${log.id}'),
                    title: Text(longDate(context, log.filledAt)),
                    subtitle: Text(
                        '৳${formatTaka(log.totalCost)} · ${l10n.simpleBikeFuelLitres(log.liters.toStringAsFixed(1))}'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('simpleBikeAddFuel'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () =>
              context.push('/home/maintenance/fuel/add?bikeId=$bikeId'),
          icon: const Icon(Icons.local_gas_station_outlined),
          label: Text(l10n.simpleBikeAddFuel),
        ),
      ],
    );
  }
}
