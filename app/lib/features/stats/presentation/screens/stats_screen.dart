import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../providers/rider_stats_provider.dart';

const _ranks = [
  'New Rider',
  'Weekend Rider',
  'Steady Cruiser',
  'Road Regular',
  'Seasoned Rider',
  'Veteran',
  'Road Master',
];
const _kmPerLevel = 500.0;

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(riderStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
              child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (stats) {
            final header = Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingMd, 12, AppDimensions.paddingMd, 8),
              child: Text('Your Journey', style: display(28)),
            );

            if (stats.totalRides == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights_outlined,
                                size: 56, color: AppColors.textTertiary),
                            SizedBox(height: 16),
                            Text('No rides yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 16)),
                            SizedBox(height: 8),
                            Text('Go for a ride to start your journey.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.textTertiary, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final totalKm = stats.totalDistanceKm;
            final level = (totalKm / _kmPerLevel).floor() + 1;
            final kmIntoLevel = totalKm % _kmPerLevel;
            final rank = _ranks[(level - 1).clamp(0, _ranks.length - 1)];

            final milestones = <(String, bool)>[
              ('First ride', stats.totalRides >= 1),
              ('100 km', totalKm >= 100),
              ('500 km', totalKm >= 500),
              ('10 rides', stats.totalRides >= 10),
              ('Ton-up', stats.allTimeTopSpeedKmh >= 100),
            ];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 4,
                        AppDimensions.paddingMd, AppDimensions.paddingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level / progress card
                        EditorialCard(
                          padding: const EdgeInsets.all(AppDimensions.paddingMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Level $level · $rank',
                                        style: display(18, letterSpacing: 0)),
                                  ),
                                  Text(
                                      '${kmIntoLevel.toStringAsFixed(0)}/${_kmPerLevel.toStringAsFixed(0)} km',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              EditorialProgress(kmIntoLevel / _kmPerLevel),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Badges
                        const EditorialLabel('Badges'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (name, earned) in milestones)
                              EditorialPill(name,
                                  tone: earned ? PillTone.accent : PillTone.neutral,
                                  filled: earned),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Headline stats
                        Row(
                          children: [
                            Expanded(
                              child: _BigStat(
                                value: stats.totalDistanceKm.toStringAsFixed(0),
                                unit: 'km',
                                label: 'total distance',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BigStat(
                                value: '${stats.totalRides}',
                                label: 'total rides',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _BigStat(
                                value: stats.allTimeAvgSpeedKmh.toStringAsFixed(0),
                                unit: 'km/h',
                                label: 'avg speed',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BigStat(
                                value: stats.allTimeTopSpeedKmh.toStringAsFixed(0),
                                unit: 'km/h',
                                label: 'top speed',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BigStat(
                                value: stats.avgRidingScore.toStringAsFixed(0),
                                label: 'score',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const EditorialLabel('Recent rides'),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stats.recentRides.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _RecentRideRow(ride: stats.recentRides[i]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  const _BigStat({required this.value, this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      child: StatCell(value: value, unit: unit, label: label, valueSize: 22),
    );
  }
}

class _RecentRideRow extends StatelessWidget {
  final RideEntity ride;
  const _RecentRideRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      onTap: () => context.push('/ride/summary/${ride.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(ride.startTime), style: display(14, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(
                  '${SpeedFormatter.distanceKm(ride.distanceM)} · ${SpeedFormatter.durationFromSeconds(ride.durationSeconds ?? 0)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text('${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
              style: display(14, letterSpacing: 0, color: AppColors.primary)),
        ],
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
