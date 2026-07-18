import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../forums/presentation/screens/forums_home_screen.dart';
import '../../../poi_directory/presentation/screens/places_list_screen.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../providers/ride_feed_provider.dart';

/// Social hub: Feed (Phase 2), Forums (Phase 3), Places (this phase).
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              Tab(text: 'Places'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FeedTab(),
            ForumsHomeScreen(),
            PlacesListScreen(),
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
    final feedAsync = ref.watch(publicRideFeedProvider);

    return feedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                  Text('No public rides yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
          onRefresh: () => ref.refresh(publicRideFeedProvider.future),
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _RideCard(ride: rides[i]),
          ),
        );
      },
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
                            ref.read(rideFeedNotifierProvider.notifier).toggleLike(ride.id),
                        icon: Icon(
                          ride.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                          color: ride.isLikedByCurrentUser ? AppColors.danger : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      Text('${ride.likes}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(width: 16),
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
