import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../providers/rider_stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(riderStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insights, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rider Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Your all-time riding stats',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (stats) {
          if (stats.totalRides == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights_outlined, size: 64, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text('No rides yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Go for a ride to start building your stats.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                  ],
                ),
              ),
            );
          }

          final scoreColor = stats.avgRidingScore >= 80
              ? AppColors.success
              : stats.avgRidingScore >= 60
                  ? AppColors.warning
                  : AppColors.danger;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      label: 'Avg Speed (all time)',
                      value: stats.allTimeAvgSpeedKmh.toStringAsFixed(0),
                      unit: 'km/h',
                      icon: Icons.speed,
                    ),
                    StatCard(
                      label: 'Top Speed (all time)',
                      value: stats.allTimeTopSpeedKmh.toStringAsFixed(0),
                      unit: 'km/h',
                      icon: Icons.rocket_launch_outlined,
                      valueColor: stats.allTimeTopSpeedKmh > 100 ? AppColors.warning : null,
                    ),
                    StatCard(
                      label: 'Avg Riding Score',
                      value: stats.avgRidingScore.toStringAsFixed(0),
                      unit: '/100',
                      icon: Icons.shield_outlined,
                      valueColor: scoreColor,
                    ),
                    StatCard(
                      label: 'Total Distance',
                      value: stats.totalDistanceKm.toStringAsFixed(1),
                      unit: 'km',
                      icon: Icons.route,
                    ),
                    StatCard(
                      label: 'Total Rides',
                      value: '${stats.totalRides}',
                      icon: Icons.flag_outlined,
                      valueColor: AppColors.primaryHighlight,
                    ),
                    if (stats.mostUsedBike != null)
                      StatCard(
                        label: 'Most Used Bike',
                        value: '${stats.mostUsedBike!.brand} ${stats.mostUsedBike!.model}',
                        unit: '${stats.mostUsedBike!.rideCount} rides',
                        icon: Icons.two_wheeler,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Recent Rides',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.recentRides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RecentRideRow(ride: stats.recentRides[i]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecentRideRow extends StatelessWidget {
  final RideEntity ride;
  const _RecentRideRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/ride/summary/${ride.id}'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(ride.startTime),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${SpeedFormatter.distanceKm(ride.distanceM)} · ${SpeedFormatter.durationFromSeconds(ride.durationSeconds ?? 0)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.primaryHighlight, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
