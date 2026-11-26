import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../maintenance/presentation/widgets/forecast_text.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../stats/presentation/widgets/ride_route_thumbnail.dart';
import '../widgets/simple_rides_format.dart';

/// Simple mode ride detail: the route and four numbers (distance, time, top
/// and average speed). A number the ride doesn't have shows a dash.
class SimpleRideDetailScreen extends ConsumerWidget {
  const SimpleRideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ride = ref.watch(rideDetailProvider(rideId));

    String speed(double? ms) =>
        ms == null ? simpleRidesDash : '${(ms * 3.6).toStringAsFixed(0)} km/h';

    return Scaffold(
      backgroundColor: context.palette.background,
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
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => ref.invalidate(rideDetailProvider(rideId)),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
        data: (r) => r == null
            ? Center(child: Text(l10n.simpleRidesNotFound))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  RideRouteThumbnail(rideId: rideId, height: 220),
                  for (final (label, value) in [
                    (l10n.simpleRidesDistance, simpleRidesKm(r.distanceKm)),
                    (
                      l10n.simpleRidesTime,
                      simpleRidesDuration(l10n, r.durationSeconds)
                    ),
                    (l10n.simpleRidesTopSpeed, speed(r.maxSpeedMs)),
                    (l10n.simpleRidesAvgSpeed, speed(r.avgSpeedMs)),
                  ]) ...[
                    const SizedBox(height: 12),
                    EditorialCard(
                      radius: context.shape.radiusLg,
                      padding: const EdgeInsets.all(14),
                      child: Semantics(
                        container: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EditorialLabel(label),
                            const SizedBox(height: 4),
                            Text(value, style: display(context, 28)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
