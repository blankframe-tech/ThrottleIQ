import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/i18n/numeric_locale.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../providers/simple_bike_provider.dart';
import '../widgets/simple_rides_empty_state.dart';
import '../widgets/simple_rides_format.dart';
import '../widgets/simple_rides_week_bars.dart';
import '../widgets/simple_home_help_sheet.dart';
import '../widgets/simple_section.dart';
import '../widgets/simple_settings_button.dart';
import '../widgets/simple_start_ride_button.dart';
import '../widgets/simple_theme.dart';

/// Simple mode Rides tab: the last 7 days as bars, then every finished ride
/// as a row (when, km, time, fuel cost). Tap a row for its map and numbers.
class SimpleRidesScreen extends ConsumerWidget {
  const SimpleRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bike = ref.watch(simpleBikeProvider);
    final garageLoading = ref.watch(garageProvider).isLoading;

    final Widget body;
    if (bike == null) {
      body = garageLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              SimpleEmptyState(
                icon: Icons.two_wheeler,
                title: l10n.simpleRidesNoBikeTitle,
                body: l10n.simpleRidesNoBikeBody,
                action: l10n.simpleRidesAddBike,
                onPressed: () => context.push('/home/profile/add'),
              ),
            ]);
    } else {
      final provider = rideHistoryProvider(bike.id);
      body = RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: ref.watch(provider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(mapFirestoreError(e, l10n)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('simpleRidesRetry'),
                    onPressed: () => ref.invalidate(provider),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              data: (all) {
                final rides = all
                    .where((r) =>
                        r.status != RideStatus.active &&
                        r.status != RideStatus.paused)
                    .toList()
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));
                if (rides.isEmpty) {
                  return ListView(children: [
                    SimpleEmptyState(
                      icon: Icons.route_outlined,
                      title: l10n.simpleRidesEmptyTitle,
                      body: l10n.simpleRidesEmptyBody,
                      action: l10n.simpleRidesStartRide,
                      onPressed: () => startSimpleRide(context, ref, bike.id),
                    ),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    SimpleSectionHeader(l10n.simpleRidesWeekTitle),
                    SimpleRidesWeekBars(rides: rides),
                    const SizedBox(height: 16),
                    SimpleSectionHeader(l10n.simpleRidesListTitle),
                    for (final r in rides)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RideRow(ride: r),
                      ),
                  ],
                );
              },
            ),
      );
    }

    return SimpleTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navRidesLabel),
          actions: const [SimpleEmergencyButton(), SimpleSettingsButton()],
        ),
        body: body,
      ),
    );
  }
}

class _RideRow extends ConsumerWidget {
  const _RideRow({required this.ride});

  final RideEntity ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final cost = ref.watch(rideCostProvider((
      bikeId: ride.bikeId,
      distanceKm: ride.distanceKm,
      movingSeconds: ride.movingSeconds,
      durationSeconds: ride.durationSeconds,
    )));
    final fuel = cost?.lines
        .where((l) => l.serviceType == ServiceType.fuel)
        .firstOrNull
        ?.cost;
    final secondary = TextStyle(color: palette.textSecondary);

    return EditorialCard(
      key: Key('simpleRideCard_${ride.id}'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: () => context.push('/home/simple-rides/${ride.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    DateFormat('d MMM y · h:mm a', kNumericLocale)
                        .format(ride.startTime),
                    style: secondary),
                Text(simpleRidesKm(ride.distanceKm),
                    style: display(context, 22)),
                Text(
                  [
                    simpleRidesDuration(l10n, ride.durationSeconds),
                    if (fuel != null)
                      l10n.simpleRidesFuelCost(simpleAmount(fuel)),
                  ].join(' · '),
                  style: secondary,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.textTertiary),
        ],
      ),
    );
  }
}
