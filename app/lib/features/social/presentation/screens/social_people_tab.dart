// People tab of SocialScreen: rider search, suggestions, Following list
// and the shared RiderResultTile — split out of social_screen.dart
// (issues §90.B7).
part of 'social_screen.dart';

/// People tab: a rider-only search box, and — when it's empty — the list of
/// riders the signed-in rider follows.
///
/// No "Discover" section: there is no existing backend query for rider
/// suggestions (the app has no recommendation/activity system), so this
/// tab only shows what's real — search results, and who you already follow —
/// rather than fabricating a discovery feed.
class _PeopleTab extends ConsumerStatefulWidget {
  const _PeopleTab();

  @override
  ConsumerState<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<_PeopleTab> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(_searchDebounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd,
              AppDimensions.paddingMd, AppDimensions.paddingMd, 0),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: context.palette.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: context.l10n.searchRidersHint,
              hintStyle: TextStyle(color: context.palette.textTertiary, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: context.palette.textSecondary, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.close,
                      icon: Icon(Icons.close, color: context.palette.textSecondary, size: 18),
                      onPressed: _clear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusFull),
                borderSide: BorderSide(color: context.palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusFull),
                borderSide: BorderSide(color: context.palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusFull),
                borderSide: BorderSide(color: context.palette.primary),
              ),
            ),
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? const _FollowingList()
              : _RiderSearchList(query: _query),
        ),
      ],
    );
  }
}

class _RiderSearchList extends ConsumerWidget {
  final String query;
  const _RiderSearchList({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final ridersAsync = ref.watch(_riderSearchProvider(query));
    final riders = (ridersAsync.valueOrNull ?? const <UserProfileEntity>[])
        .where((r) => r.uid != myUid)
        .toList();

    if (ridersAsync.isLoading) {
      return Center(child: CircularProgressIndicator(color: context.palette.primary));
    }
    if (ridersAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: _SectionMessage(context.l10n.couldntSearchRiders(ridersAsync.error ?? '')),
        ),
      );
    }
    if (riders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Text(
            context.l10n.nothingFoundTryUsername(query),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      itemCount: riders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => RiderResultTile(rider: riders[i]),
    );
  }
}

class _FollowingList extends ConsumerWidget {
  const _FollowingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(_followingProfilesProvider);
    // The cached suggestion list isn't rebuilt on every follow (see
    // suggestedProfilesProvider); riders followed since are hidden live here.
    final following =
        ref.watch(followingUidsProvider).valueOrNull ?? const <String>{};
    final suggestions = [
      for (final s in ref.watch(suggestedProfilesProvider).valueOrNull ??
          const <UserProfileEntity>[])
        if (!following.contains(s.uid)) s,
    ];

    return CustomScrollView(
      slivers: [
        if (suggestions.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, AppDimensions.paddingMd, AppDimensions.paddingMd, 10),
              child: EditorialLabel(context.l10n.suggestedForYou),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                // Suggestions are capped (kSuggestionCap), so the trailing
                // card is the way to everyone else.
                itemCount: suggestions.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == suggestions.length) {
                    return const _ShowMoreCard();
                  }
                  return _SuggestedRiderCard(rider: suggestions[i]);
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, AppDimensions.paddingMd, AppDimensions.paddingMd, 10),
            child: EditorialLabel(context.l10n.following),
          ),
        ),
        profilesAsync.when(
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: context.palette.primary)),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_followingProfilesProvider),
            ),
          ),
          data: (profiles) {
            if (profiles.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: context.palette.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.notFollowingAnyoneYet,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.palette.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RiderResultTile(rider: profiles[i]),
                    );
                  },
                  childCount: profiles.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SuggestedRiderCard extends ConsumerWidget {
  final UserProfileEntity rider;
  const _SuggestedRiderCard({required this.rider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/profile/${rider.uid}'),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusLg),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          children: [
            UserAvatar(photoUrl: rider.photoUrl, name: rider.bestName, radius: 24),
            const SizedBox(height: 8),
            Text(
              rider.bestName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.palette.textPrimary,
              ),
            ),
            const Spacer(),
            FollowButton(
              targetUid: rider.uid,
              variant: FollowButtonVariant.card,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowMoreCard extends StatelessWidget {
  const _ShowMoreCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/people/all'),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusLg),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.palette.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward, color: context.palette.primary),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.showMore,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.palette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One rider row in a search/following result: tap to open the profile,
/// with a follow/unfollow toggle on the right.
class RiderResultTile extends ConsumerWidget {
  final UserProfileEntity rider;
  const RiderResultTile({super.key, required this.rider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/profile/${rider.uid}'),
              borderRadius: BorderRadius.circular(context.shape.radiusMd),
              child: Row(
                children: [
                  UserAvatar(
                      photoUrl: rider.photoUrl,
                      name: rider.bestName,
                      radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rider.bestName,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.palette.textPrimary)),
                        if (rider.username != null)
                          Text('@${rider.username}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.palette.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          FollowButton(targetUid: rider.uid),
        ],
      ),
    );
  }
}
