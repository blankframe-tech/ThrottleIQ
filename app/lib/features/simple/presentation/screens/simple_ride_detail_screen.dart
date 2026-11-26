import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../stats/presentation/widgets/ride_route_thumbnail.dart';
import '../widgets/simple_rides_format.dart';
import '../widgets/simple_section.dart';
import '../widgets/simple_theme.dart';

/// Simple mode ride detail: the route, four numbers (distance, time, top
/// and average speed) and the fuel cost when it's known. A number the ride
/// doesn't have shows a dash.
class SimpleRideDetailScreen extends ConsumerWidget {
  const SimpleRideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ride = ref.watch(rideDetailProvider(rideId));

    return SimpleTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(ride.valueOrNull == null
              ? l10n.navRidesLabel
              : longDate(context, ride.valueOrNull!.startTime)),
        ),
        body: ride.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(mapFirestoreError(e, l10n)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('simpleRideDetailRetry'),
                onPressed: () => ref.invalidate(rideDetailProvider(rideId)),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
          data: (r) => r == null
              ? Center(child: Text(l10n.simpleRidesNotFound))
              : _Detail(ride: r),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.ride});

  final RideEntity ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    String speed(double? ms) =>
        ms == null ? simpleRidesDash : '${(ms * 3.6).toStringAsFixed(0)} km/h';
    // The same estimate the ride's row on the Rides tab shows.
    final fuel = ref
        .watch(rideCostProvider((
          bikeId: ride.bikeId,
          distanceKm: ride.distanceKm,
          movingSeconds: ride.movingSeconds,
          durationSeconds: ride.durationSeconds,
        )))
        ?.lines
        .where((l) => l.serviceType == ServiceType.fuel)
        .firstOrNull
        ?.cost;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        RideRouteThumbnail(rideId: ride.id, height: 220),
        const SizedBox(height: 16),
        SimpleTileGrid(children: [
          SimpleStatTile(
              value: simpleRidesKm(ride.distanceKm),
              label: l10n.simpleRidesDistance),
          SimpleStatTile(
              value: simpleRidesDuration(l10n, ride.durationSeconds),
              label: l10n.simpleRidesTime),
          SimpleStatTile(
              value: speed(ride.maxSpeedMs), label: l10n.simpleRidesTopSpeed),
          SimpleStatTile(
              value: speed(ride.avgSpeedMs), label: l10n.simpleRidesAvgSpeed),
        ]),
        if (fuel != null) ...[
          const SizedBox(height: 12),
          SimpleStatTile(
            key: const Key('simpleRideDetailFuel'),
            value: '৳${simpleAmount(fuel)}',
            label: l10n.simpleRidesFuel,
          ),
        ],
      ],
    );
  }
}
