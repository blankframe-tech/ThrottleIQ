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
import '../widgets/badge_grid.dart';
import '../widgets/ride_line_chart.dart';
import 'all_rides_screen.dart';

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
                        padding: const EdgeInsets.all(AppDimensions.paddingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights_outlined,
                                size: 56, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text('No rides yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 16)),
                            const SizedBox(height: 8),
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
            final earnedCount = badges.where((b) => b.earned).length;
            final badgeFamiliesProgress = computeBadgeProgress(stats);
            final distanceSeries =
                stats.chartRides.map((r) => r.distanceKm).toList();
            final speedSeries =
                stats.chartRides.map((r) => r.avgSpeedKmh).toList();
            // Both charts plot the same rides, so they share one date axis.
            final chartDates =
                stats.chartRides.map((r) => r.startTime).toList();

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
                        // Rider-wide totals, directly under "Your Journey" —
                        // moved off the Record screen, which had them as the
                        // *active bike's* figures. The journey is the rider's,
                        // so these are across every bike in the garage.
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                value: SpeedFormatter.distanceKm(
                                    stats.totalDistanceKm * 1000),
                                label: 'total km',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatChip(
                                value: '${stats.totalRides}',
                                label: 'rides',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatChip(
                                value: _daysSinceLastRide(stats.recentRides),
                                label: 'last ride',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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

                        // Distance / speed over time. Graphs sit above the
                        // badges: they're the part of "your journey" that
                        // changes every ride, whereas badges move rarely, and
                        // burying the trend under a wall of icons made the
                        // rarely-changing thing the loudest.
                        const EditorialLabel('Distance over time'),
                        const SizedBox(height: 10),
                        EditorialCard(
                          padding: const EdgeInsets.all(AppDimensions.paddingMd),
                          child: RideLineChart(
                            values: distanceSeries,
                            dates: chartDates,
                            unit: 'km',
                          ),
                        ),
                        const SizedBox(height: 20),
                        const EditorialLabel('Avg speed over time'),
                        const SizedBox(height: 10),
                        EditorialCard(
                          padding: const EdgeInsets.all(AppDimensions.paddingMd),
                          child: RideLineChart(
                            values: speedSeries,
                            color: AppColors.secondary,
                            dates: chartDates,
                            unit: 'km/h',
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Badges
                        Row(
                          children: [
                            const Expanded(child: EditorialLabel('Badges')),
                            Text('$earnedCount of ${badges.length} earned',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BadgeGrid(families: badgeFamiliesProgress),
                        const SizedBox(height: 24),

                        // Headline stats. Total distance and total ride count
                        // used to lead this block; they're now the chips at
                        // the top of the page, and printing them twice on one
                        // screen just made the page longer.
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
                        // Same widget the All rides page uses, over the same
                        // provider, so the two views can't disagree.
                        RideSortChips(
                          sort: sort,
                          onChanged: (option) =>
                              ref.read(rideSortProvider.notifier).state = option,
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
                        const SizedBox(height: 14),
                        // Always offered, even when every ride already fits
                        // in the ten shown: the full page carries detail and
                        // route maps this compact list deliberately doesn't.
                        _AllRidesButton(
                          total: source.length,
                          showing: visibleRides.length,
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

/// Whole days since the most recent ride. [rides] is newest-first, as
/// [RiderStatsSummary.recentRides] always is.
String _daysSinceLastRide(List<RideEntity> rides) {
  if (rides.isEmpty) return '—';
  final days = DateTime.now().difference(rides.first.startTime).inDays;
  return '${days < 0 ? 0 : days}d';
}

/// Compact figure chip. Same shape as the ones that used to sit on the
/// Record screen, so the move reads as a move rather than a redesign.
class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: display(20)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _AllRidesButton extends StatelessWidget {
  final int total;
  final int showing;
  const _AllRidesButton({required this.total, required this.showing});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      onTap: () => context.push('/rides/all'),
      child: Row(
        children: [
          Icon(Icons.list_alt_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('All rides',
                style: display(14, letterSpacing: 0, color: AppColors.primary)),
          ),
          Text('$showing of $total shown',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
        ],
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
