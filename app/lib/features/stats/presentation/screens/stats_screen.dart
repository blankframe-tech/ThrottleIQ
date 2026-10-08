import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/badges.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/ride_sort.dart';
import '../providers/badge_sync_provider.dart';
import '../providers/rider_stats_provider.dart';
import '../widgets/badge_grid.dart';
import '../widgets/ride_line_chart.dart';
import 'all_rides_screen.dart'; // For RideSortChips and AllRidesRow
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../l10n/app_localizations.dart';

List<String> _ranks(AppLocalizations l10n) => [
      l10n.rankNewRider,
      l10n.rankWeekendRider,
      l10n.rankSteadyCruiser,
      l10n.rankRoadRegular,
      l10n.rankSeasonedRider,
      l10n.rankVeteran,
      l10n.rankRoadMaster,
    ];
const _kmPerLevel = 500.0;
const int _ridesListLimit = 10;

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showDistanceChart = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(riderStatsProvider);
    final sort = ref.watch(rideSortProvider);
    ref.watch(badgeSyncProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: context.palette.primary)),
          error: (e, _) => Center(
              child: ErrorView(
                error: e,
                onRetry: () => ref.invalidate(riderStatsProvider),
              )),
          data: (stats) {
            final source =
                stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides;
            final visibleRides =
                sortRides(source, sort).take(_ridesListLimit).toList();

            if (stats.totalRides == 0) {
              return _buildEmptyState(context);
            }

            final totalKm = stats.totalDistanceKm;
            final level = (totalKm / _kmPerLevel).floor() + 1;
            final kmIntoLevel = totalKm % _kmPerLevel;
            final ranks = _ranks(context.l10n);
            final rank = ranks[(level - 1).clamp(0, ranks.length - 1)];

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: _buildHeroAndQuickStats(
                      context,
                      stats: stats,
                      level: level,
                      rank: rank,
                      kmIntoLevel: kmIntoLevel,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: context.palette.primary,
                        indicatorWeight: 3,
                        labelColor: context.palette.textPrimary,
                        unselectedLabelColor: context.palette.textSecondary,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: [
                          // Using fallback strings since there's no l10n for analytics in the app
                          const Tab(text: 'Analytics'),
                          Tab(text: context.l10n.badges),
                          const Tab(text: 'History'),
                        ],
                      ),
                      context.palette.background,
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildAnalyticsTab(context, stats),
                  _buildBadgesTab(context, stats),
                  _buildHistoryTab(
                      context, visibleRides, sort, source.length),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMd, 12, AppDimensions.paddingMd, 8),
          child: Text(context.l10n.journey, style: display(context, 28)),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_outlined,
                      size: 56, color: context.palette.textTertiary),
                  const SizedBox(height: 16),
                  Text(context.l10n.noRidesYet,
                      style: TextStyle(
                          color: context.palette.textSecondary,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(context.l10n.goRideStartJourney,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.palette.textTertiary, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAndQuickStats(
    BuildContext context, {
    required dynamic stats,
    required int level,
    required String rank,
    required double kmIntoLevel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMd, 12, AppDimensions.paddingMd, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.journey, style: display(context, 28)),
            ],
          ),
        ),
        // Hero Progress
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: kmIntoLevel / _kmPerLevel,
                        strokeWidth: 8,
                        backgroundColor: context.palette.border,
                        color: context.palette.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('LEVEL $level',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: context.palette.primary)),
                        const SizedBox(height: 4),
                        Text(stats.avgRidingScore.toStringAsFixed(0),
                            style: display(context, 36)),
                        Text(context.l10n.score,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.palette.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(rank, style: display(context, 20)),
                const SizedBox(height: 4),
                Text(
                    '${kmIntoLevel.toStringAsFixed(0)} / ${_kmPerLevel.toStringAsFixed(0)} km',
                    style: TextStyle(
                        fontSize: 13, color: context.palette.textSecondary)),
              ],
            ),
          ),
        ),
        // Quick Stats Grid
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _QuickStatCard(
                value: '${stats.totalRides}',
                label: context.l10n.ridesLower,
              ),
              _QuickStatCard(
                value: _daysSinceLastRide(stats.recentRides),
                label: context.l10n.lastRide,
              ),
              _QuickStatCard(
                value: stats.allTimeTopSpeedKmh.toStringAsFixed(0),
                unit: 'km/h',
                label: context.l10n.topSpeedLower,
              ),
              _QuickStatCard(
                value: stats.allTimeAvgSpeedKmh.toStringAsFixed(0),
                unit: 'km/h',
                label: context.l10n.avgSpeedLower,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, dynamic stats) {
    final distanceSeries = stats.chartRides
        .map<double>((r) => (r.distanceKm as num).toDouble())
        .toList();
    final speedSeries = stats.chartRides
        .map<double>((r) => (r.avgSpeedKmh as num).toDouble())
        .toList();
    final chartDates = stats.chartRides
        .map<DateTime>((r) => r.startTime as DateTime)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EditorialLabel(_showDistanceChart
                ? context.l10n.distanceOverTime
                : context.l10n.avgSpeedOverTime),
            Row(
              children: [
                _ToggleButton(
                  label: 'Dist',
                  isActive: _showDistanceChart,
                  onTap: () => setState(() => _showDistanceChart = true),
                ),
                const SizedBox(width: 4),
                _ToggleButton(
                  label: 'Speed',
                  isActive: !_showDistanceChart,
                  onTap: () => setState(() => _showDistanceChart = false),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        EditorialCard(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
          child: _showDistanceChart
              ? RideLineChart(
                  values: distanceSeries,
                  dates: chartDates,
                  unit: 'km',
                )
              : RideLineChart(
                  values: speedSeries,
                  color: context.palette.secondary,
                  dates: chartDates,
                  unit: 'km/h',
                ),
        ),
      ],
    );
  }

  Widget _buildBadgesTab(BuildContext context, dynamic stats) {
    final badges = computeBadges(stats);
    final earnedCount = badges.where((b) => b.earned).length;
    final badgeFamiliesProgress = computeBadgeProgress(stats);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        Row(
          children: [
            Expanded(child: EditorialLabel(context.l10n.badges)),
            Text(context.l10n.badgesEarnedCount(earnedCount, badges.length),
                style: TextStyle(
                    fontSize: 11, color: context.palette.textTertiary)),
          ],
        ),
        const SizedBox(height: 16),
        BadgeGrid(families: badgeFamiliesProgress),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context, List<RideEntity> visibleRides,
      RideSort sort, int totalRides) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMd, 16, AppDimensions.paddingMd, 12),
            child: RideSortChips(
              sort: sort,
              onChanged: (option) =>
                  ref.read(rideSortProvider.notifier).state = option,
            ),
          ),
        ),
        SliverPadding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          sliver: visibleRides.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(context.l10n.noRidesYetDot,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: context.palette.textSecondary)),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == visibleRides.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 24),
                          child: _AllRidesButton(
                            total: totalRides,
                            showing: visibleRides.length,
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AllRidesRow(ride: visibleRides[i], sort: sort),
                      );
                    },
                    childCount: visibleRides.length + 1,
                  ),
                ),
        ),
      ],
    );
  }
}

String _daysSinceLastRide(List<RideEntity> rides) {
  if (rides.isEmpty) return '—';
  final days = DateTime.now().difference(rides.first.startTime).inDays;
  return '${days < 0 ? 0 : days}d';
}

class _QuickStatCard extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  const _QuickStatCard({required this.value, this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(context, 22)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ]
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: context.palette.textSecondary)),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? context.palette.surfaceVariant : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? context.palette.textPrimary
                : context.palette.textSecondary,
          ),
        ),
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
          Icon(Icons.list_alt_outlined,
              size: 18, color: context.palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.l10n.allRides,
                style: display(context, 14,
                    letterSpacing: 0, color: context.palette.primary)),
          ),
          Text(context.l10n.shown(showing, total),
              style: TextStyle(
                  fontSize: 12, color: context.palette.textTertiary)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right,
              size: 18, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _backgroundColor;

  _SliverTabBarDelegate(this._tabBar, this._backgroundColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
