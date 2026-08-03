import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/ride_sort.dart';
import '../providers/badge_sync_provider.dart';
import '../providers/rider_stats_provider.dart';
import '../widgets/ride_line_chart.dart';

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

/// How many rides the list shows. Ranking always considers the full history;
/// this only caps what's drawn, so "Top speed" really is your fastest ten
/// rides ever rather than the fastest of your ten most recent.
const int _ridesListLimit = 10;

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(riderStatsProvider);
    final sort = ref.watch(rideSortProvider);
    ref.watch(badgeSyncProvider); // fire-and-forget; UI never awaits this

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: AppColors.danger))),
          data: (stats) {
            // Sort the whole history, then cap — never the other way round.
            // Falls back to recentRides so an older cached summary (which has
            // no allRides) still renders its list instead of going blank.
            final source =
                stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides;
            final visibleRides =
                sortRides(source, sort).take(_ridesListLimit).toList();

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
                  Expanded(
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
            final badges = computeBadges(stats);
            final distanceSeries =
                stats.chartRides.map((r) => r.distanceKm).toList();
            final speedSeries =
                stats.chartRides.map((r) => r.avgSpeedKmh).toList();

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
                                      style: TextStyle(
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
                            for (final badge in badges)
                              EditorialPill(badge.def.name,
                                  tone: badge.earned ? PillTone.accent : PillTone.neutral,
                                  filled: badge.earned),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Distance / speed over time
                        const EditorialLabel('Distance over time'),
                        const SizedBox(height: 10),
                        EditorialCard(
                          padding: const EdgeInsets.all(AppDimensions.paddingMd),
                          child: RideLineChart(values: distanceSeries),
                        ),
                        const SizedBox(height: 20),
                        const EditorialLabel('Avg speed over time'),
                        const SizedBox(height: 10),
                        EditorialCard(
                          padding: const EdgeInsets.all(AppDimensions.paddingMd),
                          child: RideLineChart(
                              values: speedSeries, color: AppColors.secondary),
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

                        EditorialLabel(
                          sort == RideSort.recent ? 'Recent rides' : 'Your rides',
                        ),
                        const SizedBox(height: 10),
                        // Sort chips. Ranking reads from stats.allRides (the
                        // full history) and truncates AFTER sorting — sorting
                        // the already-truncated recent list would show "your
                        // fastest" while only ever considering your last ten.
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: RideSort.values.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final option = RideSort.values[i];
                              return GestureDetector(
                                onTap: () => ref
                                    .read(rideSortProvider.notifier)
                                    .state = option,
                                child: EditorialPill(
                                  option.label,
                                  filled: option == sort,
                                  tone: option == sort
                                      ? PillTone.accent
                                      : PillTone.neutral,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (visibleRides.isEmpty)
                          Text('No rides yet.',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visibleRides.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _RecentRideRow(ride: visibleRides[i], sort: sort),
                          ),
                        if (stats.allRides.length > visibleRides.length) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Showing ${visibleRides.length} of ${stats.allRides.length} rides',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ],
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

  /// The active ordering, so the trailing figure shows what the list is
  /// actually ranked by. Sorting by distance while every row still showed
  /// km/h would look like the sort had silently failed.
  final RideSort sort;

  const _RecentRideRow({required this.ride, required this.sort});

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
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Recency has no figure of its own — the date on the left already
          // is the sort key — so it keeps showing top speed, as before.
          Text(
            sort.trailingValue(ride) ??
                '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
            style: display(14, letterSpacing: 0, color: AppColors.primary),
          ),
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
