import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/badges.dart';
import '../../../../core/utils/rider_stats.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/ride_sort.dart';
import '../providers/badge_sync_provider.dart';
import '../providers/rider_stats_provider.dart';
import '../widgets/badge_grid.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../maintenance/presentation/providers/fuel_provider.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';
import '../widgets/analytics_chart_card.dart';
import 'all_rides_screen.dart'; // For RideSortChips and AllRidesRow
import 'analytics_detail_screen.dart';
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
                            fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: [
                          Tab(text: context.l10n.ridesAnalyticsTab),
                          Tab(text: context.l10n.badges),
                          Tab(text: context.l10n.ridesHistoryTab),
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
                  _buildHistoryTab(context, visibleRides, sort, source.length),
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
                          color: context.palette.textSecondary, fontSize: 16)),
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
    // Deliberately compact (one slim level bar + one dense stats strip) so
    // the analytics charts start above the fold on a ~800dp phone.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMd, 8, AppDimensions.paddingMd, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.journey, style: display(context, 22)),
          const SizedBox(height: 8),
          EditorialCard(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(context.l10n.riderLevel(level).toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: context.palette.primary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rank,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: display(context, 14, letterSpacing: 0)),
                    ),
                    Text(stats.avgRidingScore.toStringAsFixed(0),
                        style: display(context, 16)),
                    const SizedBox(width: 3),
                    Text(context.l10n.score,
                        style: TextStyle(
                            fontSize: 10,
                            color: context.palette.textSecondary)),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: kmIntoLevel / _kmPerLevel,
                          minHeight: 5,
                          backgroundColor: context.palette.border,
                          color: context.palette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                        '${kmIntoLevel.toStringAsFixed(0)} / ${_kmPerLevel.toStringAsFixed(0)} km',
                        style: TextStyle(
                            fontSize: 10, color: context.palette.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          EditorialCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _QuickStatCard(
                    value: '${stats.totalRides}',
                    label: context.l10n.ridesLower,
                  ),
                  const _QuickStatDivider(),
                  _QuickStatCard(
                    value: _daysSinceLastRide(stats.recentRides),
                    label: context.l10n.lastRide,
                  ),
                  const _QuickStatDivider(),
                  _QuickStatCard(
                    value: stats.allTimeTopSpeedKmh.toStringAsFixed(0),
                    unit: 'km/h',
                    label: context.l10n.topSpeedLower,
                  ),
                  const _QuickStatDivider(),
                  _QuickStatCard(
                    value: stats.allTimeAvgSpeedKmh.toStringAsFixed(0),
                    unit: 'km/h',
                    label: context.l10n.avgSpeedLower,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, RiderStatsSummary stats) {
    final rides =
        stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides;
    final bikes = ref.watch(allBikesProvider).valueOrNull ?? const [];
    final bikeNames = {for (final b in bikes) b.id: b.displayName};
    final l10n = context.l10n;
    String bikeName(String id) => bikeNames[id] ?? l10n.analyticsUnknownBike;
    final now = DateTime.now();
    final fuelLogs = ref.watch(userFuelLogsProvider).valueOrNull ?? const [];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMd, 10, AppDimensions.paddingMd, 24),
      itemCount: AnalyticsChart.values.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Text(l10n.analyticsTapForDetails,
              style:
                  TextStyle(fontSize: 11, color: context.palette.textTertiary));
        }
        final chart = AnalyticsChart.values[i - 1];
        final fuel = isFuelChart(chart);
        final points = fuel
            ? buildFuelPreviewSeries(chart, fuelLogs, now: now)
            : buildPreviewSeries(chart, rides, now: now);
        final insights = fuel
            ? buildFuelInsights(chart, fuelLogs, points)
            : buildInsights(chart, rides, points, now: now);
        return AnalyticsChartCard(
          chart: chart,
          points: points,
          bikeName: bikeName,
          insight: insightText(l10n, chart, insights.first, bikeName: bikeName),
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => AnalyticsDetailScreen(
                chart: chart,
                rides: rides,
                bikeNames: bikeNames,
                fuelLogs: fuelLogs,
              ),
            ),
          ),
        );
      },
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
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: display(context, 16),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: context.palette.textSecondary),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10, color: context.palette.textSecondary)),
        ],
      ),
    );
  }
}

class _QuickStatDivider extends StatelessWidget {
  const _QuickStatDivider();

  @override
  Widget build(BuildContext context) =>
      VerticalDivider(width: 1, thickness: 1, color: context.palette.border);
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
              style:
                  TextStyle(fontSize: 12, color: context.palette.textTertiary)),
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
