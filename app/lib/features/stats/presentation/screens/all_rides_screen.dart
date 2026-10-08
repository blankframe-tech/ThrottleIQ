import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/ride_sort.dart';
import '../providers/rider_stats_provider.dart';
import '../widgets/ride_route_thumbnail.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../ride_sort_l10n.dart';

/// How many rides are revealed at a time.
const int allRidesPageSize = 20;

/// Every ride the rider has recorded, in full detail — the Rides tab's
/// compact list shows ten and links here.
///
/// **Lazy infinite scroll, not paged navigation.** The rides are already in
/// memory (riderStatsProvider reads the whole local table in one go), so page
/// buttons would be pure ceremony over a list we already hold. The cost that
/// actually needs managing is *rendering*: each row can carry a map, and a
/// map is tiles plus a polyline. Revealing 20 more rows as the rider reaches
/// the end keeps that bounded while preserving one continuous list that
/// reads the same way as the compact one it came from.
class AllRidesScreen extends ConsumerStatefulWidget {
  const AllRidesScreen({super.key});

  @override
  ConsumerState<AllRidesScreen> createState() => _AllRidesScreenState();
}

class _AllRidesScreenState extends ConsumerState<AllRidesScreen> {
  final _controller = ScrollController();
  int _visible = allRidesPageSize;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    // Reveal the next page a little before the end so the list never
    // visibly stalls at the bottom.
    if (position.pixels >= position.maxScrollExtent - 600) {
      setState(() => _visible += allRidesPageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(riderStatsProvider);
    final sort = ref.watch(rideSortProvider);

    // Re-sorting reorders the whole history, so the rows already revealed are
    // no longer the rows the rider was looking at. Collapsing back to one
    // page keeps "load more" meaning "more of *this* order" and drops the
    // maps of rows that just moved out of reach.
    ref.listen(rideSortProvider, (_, __) {
      setState(() => _visible = allRidesPageSize);
      if (_controller.hasClients) _controller.jumpTo(0);
    });

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: Icon(Icons.arrow_back, color: context.palette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(context.l10n.allRides, style: display(context, 20, letterSpacing: 0)),
      ),
      body: SafeArea(
        top: false,
        child: statsAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: context.palette.primary)),
          error: (e, _) => Center(
              child: ErrorView(
                error: e,
                onRetry: () => ref.invalidate(riderStatsProvider),
              )),
          data: (stats) {
            // Same fallback as the Rides tab: an older cached summary has no
            // allRides, and an empty page would be a lie.
            final source =
                stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides;
            final sorted = sortRides(source, sort);
            final shown = sorted.take(_visible).toList();
            final hasMore = sorted.length > shown.length;

            if (sorted.isEmpty) {
              return Center(
                child: Text(context.l10n.noRidesYetDot,
                    style: TextStyle(
                        fontSize: 14, color: context.palette.textSecondary)),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingMd, 4, AppDimensions.paddingMd, 4),
                  child: RideSortChips(
                    sort: sort,
                    onChanged: (option) =>
                        ref.read(rideSortProvider.notifier).state = option,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingMd, 8, AppDimensions.paddingMd, 8),
                  child: Text(
                    context.l10n.showing(shown.length, sorted.length),
                    style:
                        TextStyle(fontSize: 12, color: context.palette.textTertiary),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _controller,
                    padding: const EdgeInsets.fromLTRB(
                        AppDimensions.paddingMd,
                        0,
                        AppDimensions.paddingMd,
                        AppDimensions.paddingLg),
                    itemCount: shown.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i >= shown.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: context.palette.primary),
                            ),
                          ),
                        );
                      }
                      return AllRidesRow(ride: shown[i], sort: sort);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The Rides tab's sort chips, lifted out so both views run the same control
/// over the same [RideSort] rather than two copies that can drift.
class RideSortChips extends StatelessWidget {
  final RideSort sort;
  final ValueChanged<RideSort> onChanged;

  const RideSortChips({super.key, required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RideSort.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final option = RideSort.values[i];
          // issues §101.R9: announce the chip as a button and which sort
          // is active.
          return Semantics(
            button: true,
            selected: option == sort,
            inMutuallyExclusiveGroup: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(option),
              child: EditorialPill(
                option.localizedLabel(context.l10n),
                filled: option == sort,
                tone: option == sort ? PillTone.accent : PillTone.neutral,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A full-detail ride row: date and time, the four figures that matter, and
/// the route where one was recorded.
class AllRidesRow extends StatelessWidget {
  final RideEntity ride;
  final RideSort sort;

  const AllRidesRow({super.key, required this.ride, required this.sort});

  @override
  Widget build(BuildContext context) {
    final score = rideScoreOf(ride);
    final isCrash = ride.status == RideStatus.crash;
    final borderColor = isCrash
        ? context.palette.danger
        : context.palette.primary.withValues(alpha: 0.4);
    final shadowColor = isCrash
        ? context.palette.danger.withValues(alpha: 0.2)
        : context.palette.primary.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: () => context.push('/ride/summary/${ride.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Map Section
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RideRouteThumbnail(rideId: ride.id, height: 120),
                  // Gradient for text readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Date and Score Overlay
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatRideDate(ride.startTime),
                                style: display(context, 16, letterSpacing: 0, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(formatRideTime(ride.startTime),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                        // Circular Score Gauge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: score >= 90
                                  ? context.palette.success
                                  : (score >= 70 ? Colors.white54 : context.palette.attention),
                              width: 2,
                            ),
                            color: Colors.black54,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            score.toString(),
                            style: display(context, 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Stats Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Figure(
                            label: context.l10n.distanceLower,
                            value: SpeedFormatter.distanceKm(ride.distanceM)),
                      ),
                      Expanded(
                        child: _Figure(
                            label: context.l10n.durationStatLabel,
                            value: SpeedFormatter.durationFromSeconds(
                                ride.durationSeconds ?? 0)),
                      ),
                      Expanded(
                        child: _Figure(
                            label: context.l10n.avgSpeedStatLabel,
                            value: '${ride.avgSpeedKmh.toStringAsFixed(0)} km/h'),
                      ),
                      Expanded(
                        child: _Figure(
                            label: context.l10n.topLower,
                            value: '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Pills and alerts
                  Row(
                    children: [
                      if (isCrash) ...[
                        Semantics(
                          label: context.l10n.crashSuspectedBadge,
                          child: EditorialPill(context.l10n.crashSuspectedBadge,
                              tone: PillTone.overdue),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (ride.routeName != null) ...[
                        EditorialPill(context.l10n.followedRoutePill(ride.routeName!),
                            tone: PillTone.neutral, filled: false),
                        const SizedBox(width: 8),
                      ],
                      if (ride.hardBrakeCount +
                              ride.rapidAccelCount +
                              ride.highJerkCount >
                          0)
                        Expanded(
                          child: Text(
                            context.l10n.hardBrakesRapidAccel(ride.hardBrakeCount, ride.rapidAccelCount, ride.highJerkCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: context.palette.textTertiary),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: display(context, 13, letterSpacing: 0)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: context.palette.textTertiary)),
      ],
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatRideDate(DateTime dt) =>
    '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

String formatRideTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${dt.hour < 12 ? 'am' : 'pm'}';
}
