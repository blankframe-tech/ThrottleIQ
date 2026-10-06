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
    final activeGroupRides = ref.watch(activeGroupRidesForUserProvider).valueOrNull ??
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
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
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
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                      itemCount: activeGroupRides.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _LiveGroupRideCard(ride: activeGroupRides[i]),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(feedSortProvider.notifier).state = FeedSort.following,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: sort == FeedSort.following ? context.palette.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sort == FeedSort.following ? context.palette.primary : context.palette.border),
                          ),
                          child: Text(
                            context.l10n.following,
                            style: TextStyle(
                              color: sort == FeedSort.following ? context.palette.background : context.palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref.read(feedSortProvider.notifier).state = FeedSort.recent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: sort == FeedSort.recent ? context.palette.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sort == FeedSort.recent ? context.palette.primary : context.palette.border),
                          ),
                          child: Text(
                            context.l10n.discover,
                            style: TextStyle(
                              color: sort == FeedSort.recent ? context.palette.background : context.palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                      child: CircularProgressIndicator(color: context.palette.primary),
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
                      child: CircularProgressIndicator(color: context.palette.primary),
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
                                  color: context.palette.textSecondary, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final showFooter =
                  feed.isLoadingMore || feed.hasMore || feed.error != null;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < rides.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _RideCard(ride: rides[index]),
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

    return GestureDetector(
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
                  decoration: BoxDecoration(color: context.palette.primary, shape: BoxShape.circle),
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
                          border: Border.all(color: context.palette.surface, width: 2),
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
                          border: Border.all(color: context.palette.surface, width: 2),
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
                style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.tryAgain)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(context.l10n.youreAllCaughtUp,
            style: TextStyle(color: context.palette.textTertiary, fontSize: 13)),
      ),
    );
  }
}

class _RideCard extends ConsumerStatefulWidget {
  final SharedRideEntity ride;
  const _RideCard({required this.ride});

  @override
  ConsumerState<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends ConsumerState<_RideCard> {
  bool _expanded = false;
  bool _loadingComments = false;
  List<RideCommentEntity>? _comments;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpanded() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _comments == null) {
      await _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    setState(() => _loadingComments = true);
    try {
      final comments = await RideShareRepository().getComments(widget.ride.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    // The rider's profile name (nickname → display name), same as every
    // other place their name is shown — not the raw Auth displayName.
    final me = ref.read(myProfileProvider).valueOrNull;

    _commentController.clear();
    try {
      await RideShareRepository().addComment(
        rideId: widget.ride.id,
        userId: user.uid,
        userName: me?.bestName ?? user.displayName ?? context.l10n.riderFallbackName,
        userPhotoUrl: me?.photoUrl ?? user.photoURL ?? '',
        text: text,
      );
      ref
          .read(rideFeedNotifierProvider.notifier)
          .incrementCommentCount(widget.ride.id);
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedPostComment(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: () =>
                  context.push('/rides/shared/${ride.id}', extra: ride),
              borderRadius: BorderRadius.circular(context.shape.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.two_wheeler,
                              color: context.palette.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride.bikeName,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textPrimary),
                              ),
                              Text(ride.bikeType,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.palette.textSecondary)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/profile/${ride.userId}'),
                          child: Text(
                            ride.userName,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.palette.textSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: context.palette.textTertiary, size: 18),
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'report') {
                              ReportBottomSheet.show(
                                context,
                                reportedId: ride.userId,
                                contentType: 'ride',
                                contentId: ride.id,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'report',
                              child: Text(context.l10n.reportRide),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (ride.ridingScore != null) ...[
                      const SizedBox(height: 10),
                      _RidingScoreChip(score: ride.ridingScore!),
                    ],
                    if ((ride.caption ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        ride.caption!.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, color: context.palette.textPrimary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildMedia(ride),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('${ride.distanceKm.toStringAsFixed(1)} km',
                            context.l10n.distanceLabel),
                        _divider(),
                        _stat('${ride.durationMinutes} min', context.l10n.duration),
                        _divider(),
                        _stat('${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
                            context.l10n.maxSpeed),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: context.palette.border),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          tooltip: context.l10n.upvote,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () => ref
                              .read(rideFeedNotifierProvider.notifier)
                              .vote(ride.id, 1),
                          icon: Icon(
                            Icons.arrow_upward,
                            color: ride.myVote == 1
                                ? context.palette.primary
                                : context.palette.textSecondary,
                            size: 20,
                          ),
                        ),
                        Text('${ride.netScore}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.palette.textPrimary)),
                        IconButton(
                          tooltip: context.l10n.downvote,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () => ref
                              .read(rideFeedNotifierProvider.notifier)
                              .vote(ride.id, -1),
                          icon: Icon(
                            Icons.arrow_downward,
                            color: ride.myVote == -1
                                ? context.palette.danger
                                : context.palette.textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _toggleExpanded,
                          borderRadius:
                              BorderRadius.circular(context.shape.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    color: context.palette.textSecondary, size: 18),
                                const SizedBox(width: 6),
                                Text('${ride.comments}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: context.palette.textSecondary)),
                                const SizedBox(width: 4),
                                Icon(
                                    _expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: context.palette.textSecondary,
                                    size: 16),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(context.l10n.details,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.primary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right,
                                size: 16, color: context.palette.primary),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 0,
                    AppDimensions.paddingMd, AppDimensions.paddingMd),
                child: _buildComments(),
              ),
          ],
        ),
      ),
    );
  }

  /// Media: the route map is always shown (Strava-style) and, when the rider
  /// attached photos, it becomes the lead tile of one collage with them
  /// ([RideMediaCollage]) rather than a separate panel beside them.
  /// [RideRouteMap] renders its own placeholder when the polyline is empty
  /// (privacy clipping can legitimately empty a short ride).
  ///
  /// Tapping a photo opens the swipeable full-screen gallery; tapping the map
  /// opens the shared ride details screen.
  Widget _buildMedia(SharedRideEntity ride) {
    return RideMediaCollage.network(
      urls: ride.photoUrls,
      map: RideRouteMap(polyline: ride.polyline, radius: 0),
      onMapTap: () => context.push('/rides/shared/${ride.id}', extra: ride),
    );
  }

  Widget _buildComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: context.palette.border),
        const SizedBox(height: 8),
        if (_loadingComments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: CircularProgressIndicator(color: context.palette.primary)),
          )
        else if ((_comments ?? const []).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.l10n.noCommentsYet,
                style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
          )
        else
          ..._comments!.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${c.userName}  ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary),
                      ),
                      TextSpan(
                        text: c.text,
                        style: TextStyle(
                            fontSize: 13, color: context.palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: context.palette.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.addComment,
                  hintStyle: TextStyle(color: context.palette.textTertiary),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            IconButton(
              tooltip: context.l10n.send,
              icon: Icon(Icons.send, color: context.palette.primary, size: 20),
              onPressed: _submitComment,
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.palette.textPrimary)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: context.palette.textSecondary)),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: context.palette.border.withValues(alpha: 0.3),
      );
}

/// Small tier-colored riding-score pill for a feed card — the "gamified"
/// half of sharing a ride's score: a number a rider earned, not just another
/// stat. Only shown when [SharedRideEntity.ridingScore] is non-null (see
/// that getter's doc comment).
class _RidingScoreChip extends StatelessWidget {
  final int score;

  const _RidingScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tier = ridingScoreTier(score);
    final (color, label, icon) = switch (tier) {
      RidingScoreTier.smooth => (
          context.palette.success,
          l10n.scoreSmoothLabel,
          Icons.emoji_events
        ),
      RidingScoreTier.steady => (
          context.palette.attention,
          l10n.scoreSteadyLabel,
          Icons.thumb_up_alt_rounded
        ),
      RidingScoreTier.aggressive => (
          context.palette.danger,
          l10n.scoreAggressiveLabel,
          Icons.warning_amber_rounded
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.shape.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text('$score',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text('· $label', style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
