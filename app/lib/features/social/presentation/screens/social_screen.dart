import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
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
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/feed_sort.dart';
import '../providers/follow_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/ride_feed_provider.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';

/// How long the header search waits after the last keystroke before querying.
/// Rider search runs a Firestore prefix query per keystroke otherwise.
const _searchDebounce = Duration(milliseconds: 250);

/// Riders matching the header search box. Autodisposed per query string so a
/// long session doesn't accumulate one cached result list per typed prefix.
final _riderSearchProvider =
    FutureProvider.autoDispose.family<List<UserProfileEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final repo = ProfileRepository();
  // An email needs the exact-match query; anything else (with or without a
  // leading @) is a username prefix. Same rule the old Find-riders sheet used.
  final looksLikeEmail = q.contains('@') && q.contains('.') && !q.startsWith('@');
  return looksLikeEmail ? repo.searchByEmail(q) : repo.searchByUsername(q);
});

/// Forums matching the header search box. See
/// [ForumRepository.searchForums] for why this is an in-memory filter.
final _forumSearchProvider =
    FutureProvider.autoDispose.family<List<ForumEntity>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return ForumRepository().searchForums(q);
});

/// Social hub: Feed (Phase 2), Forums (Phase 3). Places moved to its own
/// bottom-nav tab in Epic E.
///
/// The header holds one search box covering both riders and forums — a rider
/// looking for "Royal Enfield" shouldn't have to know whether that's a person
/// or a board before they can type it. Results replace the tab body while the
/// box has text, so searching never loses the rider's place in the feed.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _controller = TextEditingController();

  /// The debounced query the results panel actually runs, as opposed to the
  /// raw controller text which changes on every keystroke.
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
    // Clearing is immediate — waiting 250 ms to dismiss the results panel
    // after the rider empties the box feels broken.
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
    final searching = _query.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          titleSpacing: AppDimensions.paddingMd,
          title: SizedBox(
            height: 40,
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: 'Search riders and forums',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                        onPressed: _clear,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              color: AppColors.primary,
              tooltip: 'Messages',
              onPressed: () => context.push('/chats'),
            ),
          ],
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Feed'),
              Tab(text: 'Forums'),
            ],
          ),
        ),
        // Stacked rather than swapped so the TabBarView keeps its state (feed
        // scroll position, expanded comment threads) while results are up.
        body: Stack(
          children: [
            const TabBarView(
              children: [
                _FeedTab(),
                ForumsHomeScreen(),
              ],
            ),
            if (searching)
              Positioned.fill(
                child: Container(
                  color: AppColors.background,
                  child: _SearchResults(query: _query),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Combined rider + forum results, grouped by type. Each group loads and
/// fails independently — a forum-search error shouldn't hide riders that
/// came back fine.
class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final ridersAsync = ref.watch(_riderSearchProvider(query));
    final forumsAsync = ref.watch(_forumSearchProvider(query));

    // Never offer to follow yourself.
    final riders =
        (ridersAsync.valueOrNull ?? const <UserProfileEntity>[])
            .where((r) => r.uid != myUid)
            .toList();
    final forums = forumsAsync.valueOrNull ?? const <ForumEntity>[];

    final stillLoading = ridersAsync.isLoading || forumsAsync.isLoading;
    if (!stillLoading && riders.isEmpty && forums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Text(
            'Nothing found for "$query".\nTry a @username, an email, or a forum name.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        const EditorialLabel('Riders'),
        const SizedBox(height: 10),
        if (ridersAsync.isLoading)
          const _SectionSpinner()
        else if (ridersAsync.hasError)
          _SectionMessage('Couldn\'t search riders: ${ridersAsync.error}')
        else if (riders.isEmpty)
          const _SectionMessage('No riders match that.')
        else
          for (final rider in riders) ...[
            _RiderResultTile(rider: rider),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 16),
        const EditorialLabel('Forums'),
        const SizedBox(height: 10),
        if (forumsAsync.isLoading)
          const _SectionSpinner()
        else if (forumsAsync.hasError)
          _SectionMessage('Couldn\'t search forums: ${forumsAsync.error}')
        else if (forums.isEmpty)
          const _SectionMessage('No forums match that.')
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
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
}

class _SectionMessage extends StatelessWidget {
  final String text;
  const _SectionMessage(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
}

class _ForumResultTile extends StatelessWidget {
  final ForumEntity forum;
  const _ForumResultTile({required this.forum});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/forums/${forum.id}'),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.forum_outlined, color: AppColors.primary, size: 20),
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
                          color: AppColors.textPrimary)),
                  Text('${forum.followerCount} followers · ${forum.postCount} posts',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(rideFeedProvider);
    final sort = ref.watch(feedSortProvider);

    return Column(
      children: [
        // Sort/filter chips sit where "Find riders" used to — search now lives
        // in the header, and this is the row a rider looks at when deciding
        // what the feed should show them.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd,
              AppDimensions.paddingMd, AppDimensions.paddingMd, 0),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: FeedSort.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final option = FeedSort.values[i];
                return GestureDetector(
                  onTap: () => ref.read(feedSortProvider.notifier).state = option,
                  child: EditorialPill(
                    option.label,
                    filled: option == sort,
                    tone: option == sort ? PillTone.accent : PillTone.neutral,
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: feedAsync.when(
            loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) =>
                ErrorView(error: e, onRetry: () => ref.invalidate(rideFeedProvider)),
            data: (_) {
              // "Following" filters against the follow graph, so until that
              // has loaded the filtered feed is empty for a reason that has
              // nothing to do with who the rider follows — show the spinner
              // rather than a wrong "nobody you follow has posted".
              if (sort == FeedSort.following &&
                  ref.watch(followingUidsProvider).isLoading) {
                return Center(
                    child: CircularProgressIndicator(color: AppColors.primary));
              }
              final rides = ref.watch(visibleFeedProvider);
              if (rides.isEmpty) {
                // "Following" filtering to nothing is a different situation
                // from an empty feed, and needs a different way out.
                final following = sort == FeedSort.following;
                return Center(
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
                            color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(following ? 'Nothing from your riders yet' : 'No rides yet',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                            following
                                ? 'Search for riders above and follow them to fill this in.'
                                : 'Share a ride from its summary screen to get things started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(rideFeedProvider.future),
                color: AppColors.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _RideCard(ride: rides[i]),
                ),
              );
            },
          ),
        ),
      ],
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
      ref.read(rideFeedNotifierProvider.notifier).incrementCommentCount(widget.ride.id);
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
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
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.two_wheeler, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.bikeName,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(ride.bikeType,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(ride.userName,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: AppColors.textTertiary, size: 18),
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
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('Report Ride'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if ((ride.caption ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      ride.caption!.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildMedia(ride),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${ride.distanceKm.toStringAsFixed(1)} km', 'Distance'),
                      _divider(),
                      _stat('${ride.durationMinutes} min', 'Duration'),
                      _divider(),
                      _stat('${ride.maxSpeedKmh.toStringAsFixed(0)} km/h', 'Max Speed'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () =>
                            ref.read(rideFeedNotifierProvider.notifier).vote(ride.id, 1),
                        icon: Icon(
                          Icons.arrow_upward,
                          color: ride.myVote == 1 ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      Text('${ride.netScore}',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () =>
                            ref.read(rideFeedNotifierProvider.notifier).vote(ride.id, -1),
                        icon: Icon(
                          Icons.arrow_downward,
                          color: ride.myVote == -1 ? AppColors.danger : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text('${ride.comments}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const Spacer(),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingMd, 0, AppDimensions.paddingMd, AppDimensions.paddingMd),
              child: _buildComments(),
            ),
        ],
      ),
    );
  }

  /// Media strip: the route map is always shown (Strava-style). Rider photos,
  /// when present, sit beside it — photos and map each taking half the card
  /// width — instead of replacing it. [RideRouteMap] renders its own
  /// placeholder when the polyline is empty (privacy clipping can legitimately
  /// empty a short ride).
  ///
  /// Multiple photos are a swipeable strip ([_PhotoStrip]) rather than a
  /// collage: the map already owns half the card, so a 2×2 collage of three
  /// photos would leave each one about 75 px wide — too small to read on a
  /// phone. The strip keeps every photo at the full size a single photo used
  /// to get, renders identically for 1, 2 or 3, and can't overflow, because
  /// its width is whatever the Row hands it rather than something that grows
  /// with the photo count.
  Widget _buildMedia(SharedRideEntity ride) {
    const mediaHeight = 160.0;
    
    Widget buildMap(double h) => RideRouteMap(
      polyline: ride.polyline,
      height: h,
      radius: AppDimensions.radiusLg,
    );

    final map = GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog.fullscreen(
            backgroundColor: AppColors.background,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RideRouteMap(
                    polyline: ride.polyline,
                    height: double.infinity,
                    radius: 0,
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: AppColors.textPrimary),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: buildMap(mediaHeight),
    );

    if (ride.photoUrls.isEmpty) return map;

    return SizedBox(
      height: mediaHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _PhotoStrip(urls: ride.photoUrls, height: mediaHeight)),
          const SizedBox(width: 8),
          Expanded(child: map),
        ],
      ),
    );
  }

  Widget _buildComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 8),
        if (_loadingComments)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if ((_comments ?? const []).isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No comments yet', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      TextSpan(
                        text: c.text,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: AppColors.primary, size: 20),
              onPressed: _submitComment,
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: AppColors.border);
}

/// A ride's photos as a horizontally swipeable strip, one photo per page,
/// with a "2/3" counter and page dots once there's more than one.
///
/// A single photo renders exactly as it did before multi-photo support: one
/// page, no counter, no dots.
class _PhotoStrip extends StatefulWidget {
  final List<String> urls;
  final double height;
  const _PhotoStrip({required this.urls, required this.height});

  @override
  State<_PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<_PhotoStrip> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final multiple = urls.length > 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              // A single photo shouldn't swipe at all — there's nowhere to go,
              // and a rubber-banding image reads as a broken card.
              physics: multiple
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog.fullscreen(
                        backgroundColor: Colors.black,
                        child: Stack(
                          children: [
                            InteractiveViewer(
                              child: Center(
                                child: CachedNetworkImage(
                                  imageUrl: urls[i],
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(color: Colors.white)),
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                                ),
                              ),
                            ),
                            SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: urls[i],
                    height: widget.height,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(height: widget.height, color: AppColors.background),
                    errorWidget: (_, __, ___) =>
                        Container(height: widget.height, color: AppColors.background),
                  ),
                );
              },
              onPageChanged: (i) => setState(() => _page = i),
            ),
          ),
          if (multiple) ...[
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '${_page + 1}/${urls.length}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < urls.length; i++)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? Colors.white : Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One rider row in the header search results: tap to open the profile,
/// with a follow/unfollow toggle on the right.
class _RiderResultTile extends ConsumerWidget {
  final UserProfileEntity rider;
  const _RiderResultTile({required this.rider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final isFollowingAsync = ref.watch(isFollowingProvider(rider.uid));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/profile/${rider.uid}'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Row(
                children: [
                  UserAvatar(photoUrl: rider.photoUrl, name: rider.bestName, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rider.bestName,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (rider.username != null)
                          Text('@${rider.username}',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                          fromName: me?.bestName ?? 'A rider',
                          fromPhotoUrl: me?.photoUrl,
                        );
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(isFollowing ? 'Following' : 'Follow'),
              ),
            ),
        ],
      ),
    );
  }
}
