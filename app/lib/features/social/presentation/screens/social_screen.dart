import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/riding_score.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../forums/data/repositories/forum_repository.dart';
import '../../../forums/domain/entities/forum_entity.dart';
import '../../../forums/presentation/screens/forums_home_screen.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/group_ride_entity.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/feed_sort.dart';
import '../providers/follow_providers.dart';
import '../providers/group_ride_providers.dart';
import '../providers/notification_providers.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../providers/ride_feed_provider.dart';
import '../widgets/ride_media_collage.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/i18n/l10n_context.dart';

/// How long the header search waits after the last keystroke before querying.
/// Rider search runs a Firestore prefix query per keystroke otherwise.
const _searchDebounce = Duration(milliseconds: 250);

/// Riders matching a search query — shared by the AppBar's combined search
/// (riders + forums) and the People tab's rider-only search.
final _riderSearchProvider = FutureProvider.autoDispose
    .family<List<UserProfileEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final repo = ProfileRepository();
  // An email needs the exact-match query; anything else (with or without a
  // leading @) is a username prefix. Same rule the old Find-riders sheet used.
  final looksLikeEmail =
      q.contains('@') && q.contains('.') && !q.startsWith('@');
  return looksLikeEmail ? repo.searchByEmail(q) : repo.searchByUsername(q);
});

/// Forums matching the AppBar's combined search box. See
/// [ForumRepository.searchForums] for why this is an in-memory filter.
final _forumSearchProvider = FutureProvider.autoDispose
    .family<List<ForumEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return ForumRepository().searchForums(q);
});

/// Profiles of everyone the signed-in rider follows — the People tab's
/// "Following" list. `Future.wait`s one `getProfile` per uid: the same
/// hydration shape `ride_share_repository.dart` already uses for feed votes,
/// and fine here since a follow list is small compared to a 20-post feed
/// page.
final _followingProfilesProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final ids = await ref.watch(followingIdsProvider.future);
  final repo = ProfileRepository();
  final profiles = await Future.wait(ids.map(repo.getProfile));
  return profiles.whereType<UserProfileEntity>().toList();
});

/// Social hub: Rides (the ride feed), People (rider search + who you
/// follow), and Forums. Places moved to its own bottom-nav tab in Epic E.
///
/// The AppBar's search icon opens a combined rider+forum search
/// ([_SocialSearchDelegate]) reachable from any tab, while the People tab
/// carries its own rider-only search box for the common case of "find a
/// specific rider" without leaving the tab.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          titleSpacing: AppDimensions.paddingMd,
          title: Text('Social',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.palette.textPrimary)),
          actions: [
            IconButton(
              tooltip: context.l10n.searchRidersForums,
              icon: Icon(Icons.search,
                  color: context.palette.textSecondary, size: 24),
              onPressed: () =>
                  showSearch(context: context, delegate: _SocialSearchDelegate()),
            ),
            Consumer(
              builder: (_, ref, __) => NotificationBellButton(
                  unreadCount: ref.watch(unreadNotificationCountProvider)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: context.palette.textPrimary,
            unselectedLabelColor: context.palette.textSecondary,
            indicatorColor: context.palette.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            dividerColor: context.palette.border,
            tabs: [
              Tab(text: context.l10n.navRidesLabel),
              Tab(text: context.l10n.peopleTabLabel),
              Tab(text: context.l10n.forums),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FeedTab(),
            _PeopleTab(),
            ForumsHomeScreen(),
          ],
        ),
      ),
    );
  }
}

/// Combined rider + forum search, opened from the AppBar's search icon.
/// Each group loads and fails independently — a forum-search error shouldn't
/// hide riders that came back fine.
class _SocialSearchDelegate extends SearchDelegate<void> {
  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = super.appBarTheme(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: context.palette.surface,
        foregroundColor: context.palette.textPrimary,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: context.palette.textTertiary),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: context.l10n.close,
            icon: const Icon(Icons.close),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: context.l10n.close,
        icon: const BackButtonIcon(),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _SearchResults(query: query);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _SearchResults(query: query);
}

class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final ridersAsync = ref.watch(_riderSearchProvider(query));
    final forumsAsync = ref.watch(_forumSearchProvider(query));

    // Never offer to follow yourself.
    final riders = (ridersAsync.valueOrNull ?? const <UserProfileEntity>[])
        .where((r) => r.uid != myUid)
        .toList();
    final forums = forumsAsync.valueOrNull ?? const <ForumEntity>[];

    if (query.trim().isEmpty) return const SizedBox.shrink();

    final stillLoading = ridersAsync.isLoading || forumsAsync.isLoading;
    if (!stillLoading && riders.isEmpty && forums.isEmpty) {
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

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        EditorialLabel(context.l10n.ridersLabel),
        const SizedBox(height: 10),
        if (ridersAsync.isLoading)
          const _SectionSpinner()
        else if (ridersAsync.hasError)
          _SectionMessage(context.l10n.couldntSearchRiders(ridersAsync.error ?? ''))
        else if (riders.isEmpty)
          _SectionMessage(context.l10n.noRidersMatchThat)
        else
          for (final rider in riders) ...[
            RiderResultTile(rider: rider),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 16),
        EditorialLabel(context.l10n.forums),
        const SizedBox(height: 10),
        if (forumsAsync.isLoading)
          const _SectionSpinner()
        else if (forumsAsync.hasError)
          _SectionMessage(context.l10n.couldntSearchForums(forumsAsync.error ?? ''))
        else if (forums.isEmpty)
          _SectionMessage(context.l10n.noForumsMatchThat)
        else
          for (final forum in forums) ...[
            _ForumResultTile(forum: forum),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _SectionSpinner extends StatelessWidget {
  const _SectionSpinner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child:
            Center(child: CircularProgressIndicator(color: context.palette.primary)),
      );
}

class _SectionMessage extends StatelessWidget {
  final String text;
  const _SectionMessage(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
      );
}

class _ForumResultTile extends StatelessWidget {
  final ForumEntity forum;
  const _ForumResultTile({required this.forum});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/forums/${forum.id}'),
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusMd),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.palette.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.forum_outlined,
                  color: context.palette.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(forum.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary)),
                  Text(
                      context.l10n.followersPosts(forum.followerCount, forum.postCount),
                      style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.palette.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

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
    final suggestionsAsync = ref.watch(suggestedProfilesProvider);

    return CustomScrollView(
      slivers: [
        if (suggestionsAsync.valueOrNull?.isNotEmpty == true) ...[
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
                itemCount: suggestionsAsync.value!.length > 10 ? 11 : suggestionsAsync.value!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == 10) {
                    return const _ShowMoreCard();
                  }
                  final profile = suggestionsAsync.value![i];
                  return _SuggestedRiderCard(rider: profile);
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
    final myUid = ref.watch(currentUserProvider)?.uid;
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
            if (myUid != null)
              OutlinedButton(
                onPressed: () {
                  ref.read(followRepositoryProvider).follow(myUid, rider.uid);
                  final me = ref.read(myProfileProvider).valueOrNull;
                  ref.read(notificationRepositoryProvider).notifyFollow(
                        toUid: rider.uid,
                        fromUid: myUid,
                        fromName: me?.bestName ?? context.l10n.aRider,
                        fromPhotoUrl: me?.photoUrl,
                      );
                  // Refresh suggestions and following list
                  ref.invalidate(suggestedProfilesProvider);
                  ref.invalidate(_followingProfilesProvider);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 28),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(context.l10n.follow, style: const TextStyle(fontSize: 12)),
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

    _commentController.clear();
    try {
      await RideShareRepository().addComment(
        rideId: widget.ride.id,
        userId: user.uid,
        userName: user.displayName ?? 'Rider',
        userPhotoUrl: user.photoURL ?? '',
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

/// One rider row in a search/following result: tap to open the profile,
/// with a follow/unfollow toggle on the right.
class RiderResultTile extends ConsumerWidget {
  final UserProfileEntity rider;
  const RiderResultTile({super.key, required this.rider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final isFollowingAsync = ref.watch(isFollowingProvider(rider.uid));

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
          if (myUid != null)
            isFollowingAsync.when(
              loading: () => const SizedBox(width: 80),
              error: (_, __) => const SizedBox.shrink(),
              data: (isFollowing) => OutlinedButton(
                onPressed: () {
                  final repo = ref.read(followRepositoryProvider);
                  if (isFollowing) {
                    repo.unfollow(myUid, rider.uid);
                  } else {
                    repo.follow(myUid, rider.uid);
                    final me = ref.read(myProfileProvider).valueOrNull;
                    ref.read(notificationRepositoryProvider).notifyFollow(
                          toUid: rider.uid,
                          fromUid: myUid,
                          fromName: me?.bestName ?? context.l10n.aRider,
                          fromPhotoUrl: me?.photoUrl,
                        );
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(isFollowing ? context.l10n.following : context.l10n.follow),
              ),
            ),
        ],
      ),
    );
  }
}
