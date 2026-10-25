// Rides tab of SocialScreen: the feed, Riding Now strip and ride cards —
// split out of social_screen.dart (issues §90.B7).
part of 'social_screen.dart';

/// Rides tab: the "Riding Now" strip of the signed-in rider's own active
/// group rides, a Following/Discover sort toggle, and the ride feed.
class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab();

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> {
  final _scrollController = ScrollController();

  static const _loadMoreThreshold = 600.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(rideFeedNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(rideFeedNotifierProvider);
    final sort = ref.watch(feedSortProvider);
    final activeGroupRides =
        ref.watch(activeGroupRidesForUserProvider).valueOrNull ??
            const <GroupRideEntity>[];

    return RefreshIndicator(
      onRefresh: () => ref.read(rideFeedNotifierProvider.notifier).refresh(),
      color: context.palette.primary,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeGroupRides.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMd),
                    child: Text(
                      context.l10n.ridingNowSectionTitle,
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMd),
                      itemCount: activeGroupRides.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) =>
                          _LiveGroupRideCard(ride: activeGroupRides[i]),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMd),
                  child: Row(
                    children: [
                      FeedSortPill(
                        label: context.l10n.following,
                        selected: sort == FeedSort.following,
                        onTap: () => ref.read(feedSortProvider.notifier).state =
                            FeedSort.following,
                      ),
                      const SizedBox(width: 8),
                      FeedSortPill(
                        label: context.l10n.discover,
                        selected: sort == FeedSort.recent,
                        onTap: () => ref.read(feedSortProvider.notifier).state =
                            FeedSort.recent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              if (feed.isLoading) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                          color: context.palette.primary),
                    ),
                  ),
                );
              }
              if (feed.error != null && feed.rides.isEmpty) {
                return SliverToBoxAdapter(
                  child: ErrorView(
                    error: feed.error!,
                    onRetry: () =>
                        ref.read(rideFeedNotifierProvider.notifier).refresh(),
                  ),
                );
              }
              if (sort == FeedSort.following &&
                  ref.watch(followingUidsProvider).isLoading) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                          color: context.palette.primary),
                    ),
                  ),
                );
              }
              final rides = ref.watch(visibleFeedProvider);
              if (rides.isEmpty) {
                final following = sort == FeedSort.following;
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              following
                                  ? Icons.people_outline
                                  : Icons.dynamic_feed_outlined,
                              size: 64,
                              color: context.palette.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                              following
                                  ? context.l10n.nothingFromRidersYet
                                  : context.l10n.noRidesYet,
                              style: TextStyle(
                                  color: context.palette.textSecondary,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final showFooter =
                  feed.isLoadingMore || feed.hasMore || feed.error != null;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMd, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < rides.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SharedRideFeedCard(
                            ride: rides[index],
                            onVote: (value) => ref
                                .read(rideFeedNotifierProvider.notifier)
                                .vote(rides[index].id, value),
                            onCommentAdded: () => ref
                                .read(rideFeedNotifierProvider.notifier)
                                .incrementCommentCount(rides[index].id),
                          ),
                        );
                      }
                      return _FeedFooter(
                        isLoading: feed.isLoadingMore,
                        error: feed.error,
                        onRetry: () => ref
                            .read(rideFeedNotifierProvider.notifier)
                            .loadMore(),
                      );
                    },
                    childCount: rides.length + (showFooter ? 1 : 0),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One Following/Discover sort toggle. issues §101.A4: the pills were bare
/// GestureDetectors, so the active sort was never announced.
class FeedSortPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FeedSortPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? context.palette.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? context.palette.primary
                    : context.palette.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? context.palette.background
                  : context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One card in the "Riding Now" strip: a group ride the signed-in rider is
/// currently an active member of. Avatars and the live member count come
/// from [groupRideMembersProvider] — the same per-ride roster stream the
/// group-ride map screen already watches — so this never shows more than
/// what that ride's `members` subcollection actually has.
class _LiveGroupRideCard extends ConsumerWidget {
  final GroupRideEntity ride;
  const _LiveGroupRideCard({required this.ride});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupRideMembersProvider(ride.id)).valueOrNull ??
        const <GroupRideMember>[];
    final joined = members
        .where((m) => m.status == GroupRideMemberStatus.joined)
        .toList()
      ..sort((a, b) => a.userId.compareTo(b.userId));
    final initials = joined
        .take(3)
        .map((m) => m.userName.isEmpty ? '?' : m.userName[0].toUpperCase())
        .toList();
    final overflow = joined.length - initials.length;
    final ridingCount = joined.isEmpty ? ride.memberIds.length : joined.length;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/group-ride/${ride.id}'),
        child: Container(
          width: 170,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(context.shape.radiusLg),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: context.palette.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: context.palette.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 36,
                child: Stack(
                  children: [
                    for (int i = 0; i < initials.length; i++)
                      Positioned(
                        left: i * 24.0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.palette.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.palette.surface, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              initials[i],
                              style: TextStyle(
                                color: context.palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (overflow > 0)
                      Positioned(
                        left: initials.length * 24.0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.palette.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.palette.surface, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '+$overflow',
                              style: TextStyle(
                                color: context.palette.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ride.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$ridingCount riding',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.palette.primary),
        )),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(mapFirestoreError(error!, context.l10n),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.palette.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: onRetry, child: Text(context.l10n.tryAgain)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(context.l10n.youreAllCaughtUp,
            style:
                TextStyle(color: context.palette.textTertiary, fontSize: 13)),
      ),
    );
  }
}
