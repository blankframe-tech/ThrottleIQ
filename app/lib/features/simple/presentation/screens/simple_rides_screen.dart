import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../ride/presentation/widgets/recording_gate.dart';
import '../../../stats/presentation/widgets/ride_route_thumbnail.dart';
import '../providers/simple_bike_provider.dart';
import '../widgets/simple_rides_empty_state.dart';
import '../widgets/simple_rides_format.dart';
import '../widgets/simple_rides_week_bars.dart';
import '../widgets/simple_settings_button.dart';

/// Simple mode Rides tab: the last 7 days as bars, then every finished ride
/// as a card (map, km, time, fuel cost). Tap a card for its four numbers.
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
                children: [Text(mapFirestoreError(e, l10n))],
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
                      onPressed: () => _startRide(context, ref, bike.id),
                    ),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SimpleRidesWeekBars(rides: rides),
                    for (final r in rides) ...[
                      const SizedBox(height: 12),
                      _RideCard(ride: r),
                    ],
                  ],
                );
              },
            ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(l10n.navRidesLabel),
        actions: const [SimpleSettingsButton()],
      ),
      body: body,
    );
  }

  /// The Record tab's flow: start, then the cockpit, else say why not.
  static Future<void> _startRide(
      BuildContext context, WidgetRef ref, String bikeId) async {
    await ref.read(rideRecordingProvider.notifier).startRide(bikeId: bikeId);
    if (!context.mounted) return;
    final result = ref.read(rideRecordingProvider);
    if (result.status == RecordingStatus.active) {
      context.go('/ride/active');
    } else {
      showRecordingBlockedSnackBar(context, result);
    }
  }
}

class _RideCard extends ConsumerWidget {
  const _RideCard({required this.ride});

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

    return EditorialCard(
      key: Key('simpleRideCard_${ride.id}'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/home/simple-rides/${ride.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(longDate(context, ride.startTime),
              style: TextStyle(fontSize: 12, color: palette.textTertiary)),
          RideRouteThumbnail(rideId: ride.id, height: 120),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(simpleRidesKm(ride.distanceKm), style: display(context, 20)),
              Text(simpleRidesDuration(l10n, ride.durationSeconds),
                  style: display(context, 20)),
              if (fuel != null)
                Text(l10n.simpleRidesFuelCost(simpleAmount(fuel)),
                    style: display(context, 20, color: palette.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
