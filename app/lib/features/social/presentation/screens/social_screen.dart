import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../forums/presentation/screens/forums_home_screen.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../providers/follow_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/ride_feed_provider.dart';

/// Social hub: Feed (Phase 2), Forums (Phase 3). Places moved to its own
/// bottom-nav tab in Epic E.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Social'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Feed'),
              Tab(text: 'Forums'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FeedTab(),
            ForumsHomeScreen(),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd,
              AppDimensions.paddingMd, AppDimensions.paddingMd, 0),
          child: OutlinedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.background,
              builder: (_) => const _RiderSearchSheet(),
            ),
            icon: const Icon(Icons.person_search_outlined, size: 18),
            label: const Text('Find riders'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
        Expanded(
          child: feedAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) =>
                Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
            data: (_) {
              final rides = ref.watch(rideFeedNotifierProvider);
              if (rides.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dynamic_feed_outlined, size: 64, color: AppColors.textTertiary),
                        SizedBox(height: 16),
                        Text('No rides yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Share a ride from its summary screen to get things started.',
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
                        child: const Icon(Icons.two_wheeler, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.bikeName,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(ride.bikeType,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(ride.userName,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  if (ride.photoUrl != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      child: CachedNetworkImage(
                        imageUrl: ride.photoUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            height: 160, color: AppColors.background),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
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
                          style: const TextStyle(
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
                      const Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text('${ride.comments}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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

  Widget _buildComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 8),
        if (_loadingComments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if ((_comments ?? const []).isEmpty)
          const Padding(
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
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      TextSpan(
                        text: c.text,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary, size: 20),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: AppColors.border);
}

/// Rider search: find by @username (prefix, as-you-type) or exact email,
/// with a follow/unfollow toggle per result.
class _RiderSearchSheet extends ConsumerStatefulWidget {
  const _RiderSearchSheet();

  @override
  ConsumerState<_RiderSearchSheet> createState() => _RiderSearchSheetState();
}

class _RiderSearchSheetState extends ConsumerState<_RiderSearchSheet> {
  final _controller = TextEditingController();
  List<UserProfileEntity> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    final repo = ProfileRepository();
    final looksLikeEmail = q.contains('@') && q.contains('.') && !q.startsWith('@');
    final results = looksLikeEmail
        ? await repo.searchByEmail(q)
        : await repo.searchByUsername(q);
    if (!mounted) return;
    final myUid = ref.read(currentUserProvider)?.uid;
    setState(() {
      _results = results.where((r) => r.uid != myUid).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: AppDimensions.paddingMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.paddingMd,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Find riders',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: '@username or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.trim().isEmpty
                                ? 'Search by @username or email'
                                : 'No riders found',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _RiderResultTile(rider: _results[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (rider.username != null)
                          Text('@${rider.username}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
