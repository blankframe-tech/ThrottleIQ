import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/ride_sort.dart';
import '../providers/rider_stats_provider.dart';
import '../widgets/ride_route_thumbnail.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('All rides', style: display(20, letterSpacing: 0)),
      ),
      body: SafeArea(
        top: false,
        child: statsAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: AppColors.danger))),
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
                child: Text('No rides yet.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
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
                    'Showing ${shown.length} of ${sorted.length}',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textTertiary),
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
                                  strokeWidth: 2, color: AppColors.primary),
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
          return GestureDetector(
            onTap: () => onChanged(option),
            child: EditorialPill(
              option.label,
              filled: option == sort,
              tone: option == sort ? PillTone.accent : PillTone.neutral,
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

    return EditorialCard(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      onTap: () => context.push('/ride/summary/${ride.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatRideDate(ride.startTime),
                        style: display(15, letterSpacing: 0)),
                    const SizedBox(height: 2),
                    Text(formatRideTime(ride.startTime),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              // Whatever the list is ranked by, shown large — so the ordering
              // visibly explains itself. Recency's key is the date above.
              Text(
                sort.trailingValue(ride) ??
                    SpeedFormatter.distanceKm(ride.distanceM),
                style: display(16, letterSpacing: 0, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Figure(
                    label: 'distance',
                    value: SpeedFormatter.distanceKm(ride.distanceM)),
              ),
              Expanded(
                child: _Figure(
                    label: 'duration',
                    value: SpeedFormatter.durationFromSeconds(
                        ride.durationSeconds ?? 0)),
              ),
              Expanded(
                child: _Figure(
                    label: 'avg',
                    value: '${ride.avgSpeedKmh.toStringAsFixed(0)} km/h'),
              ),
              Expanded(
                child: _Figure(
                    label: 'top',
                    value: '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              EditorialPill('Score $score',
                  tone: score >= 90
                      ? PillTone.ok
                      : (score >= 70 ? PillTone.neutral : PillTone.attention),
                  filled: false),
              const SizedBox(width: 8),
              if (ride.hardBrakeCount +
                      ride.rapidAccelCount +
                      ride.highJerkCount >
                  0)
                Expanded(
                  child: Text(
                    '${ride.hardBrakeCount} hard brakes · '
                    '${ride.rapidAccelCount} rapid accel · '
                    '${ride.highJerkCount} jerks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ),
            ],
          ),
          RideRouteThumbnail(rideId: ride.id),
        ],
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
            style: display(13, letterSpacing: 0)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
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
