import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/riding_score.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import 'ride_media_collage.dart';
import 'rider_handle.dart';

/// A shared ride as the social feed shows it: rider, caption, map + photo
/// collage, stats, votes and inline comments. Used by the feed and by a
/// rider's profile; each owner supplies how a vote and a new comment update
/// its own list ([onVote], [onCommentAdded]).
class SharedRideFeedCard extends ConsumerStatefulWidget {
  final SharedRideEntity ride;
  final void Function(int value) onVote;
  final VoidCallback? onCommentAdded;

  /// Shows a pin mark; set on rides pinned to the rider's profile.
  final bool pinned;

  /// When set, the menu offers Pin / Unpin (the rider's own profile).
  final VoidCallback? onTogglePin;

  const SharedRideFeedCard({
    super.key,
    required this.ride,
    required this.onVote,
    this.onCommentAdded,
    this.pinned = false,
    this.onTogglePin,
  });

  @override
  ConsumerState<SharedRideFeedCard> createState() => _SharedRideFeedCardState();
}

class _SharedRideFeedCardState extends ConsumerState<SharedRideFeedCard> {
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
        userName:
            me?.bestName ?? user.displayName ?? context.l10n.riderFallbackName,
        userPhotoUrl: me?.photoUrl ?? user.photoURL ?? '',
        text: text,
      );
      widget.onCommentAdded?.call();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      // The field was cleared before sending: give the rider their words back.
      if (_commentController.text.isEmpty) _commentController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .failedPostComment(mapFirestoreError(e, context.l10n))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final isMine = ref.watch(currentUserProvider)?.uid == ride.userId;
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                context.palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.two_wheeler,
                              color: context.palette.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Semantics(
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  context.push('/profile/${ride.userId}'),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: RiderHandle(
                                  uid: ride.userId,
                                  fallback: ride.userName,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: context.palette.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.pinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin,
                                size: 14, color: context.palette.primary),
                          ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            ride.bikeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.palette.textSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (widget.onTogglePin != null || !isMine)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: context.palette.textTertiary, size: 18),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'pin') widget.onTogglePin?.call();
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
                              if (widget.onTogglePin != null)
                                PopupMenuItem(
                                  value: 'pin',
                                  child: Text(widget.pinned
                                      ? context.l10n.unpinFromProfile
                                      : context.l10n.pinToProfile),
                                ),
                              if (!isMine)
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text(context.l10n.reportRide),
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
                        style: TextStyle(
                            fontSize: 14, color: context.palette.textPrimary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildMedia(ride),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('${ride.distanceKm.toStringAsFixed(1)} km',
                            context.l10n.distanceLabel),
                        _divider(),
                        _stat('${ride.durationMinutes} min',
                            context.l10n.duration),
                        _divider(),
                        _stat('${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
                            context.l10n.maxSpeed),
                        if (ride.ridingScore != null) ...[
                          _divider(),
                          _scoreStat(ride.ridingScore!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: context.palette.border),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        IconButton(
                          tooltip: context.l10n.upvote,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () => widget.onVote(1),
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
                          onPressed: () => widget.onVote(-1),
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
                                    color: context.palette.textSecondary,
                                    size: 18),
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
    final blocked =
        ref.watch(blockedUsersProvider).valueOrNull ?? const <String>{};
    final comments = (_comments ?? const <RideCommentEntity>[])
        .where((c) => !blocked.contains(c.userId))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: context.palette.border),
        const SizedBox(height: 8),
        if (_loadingComments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child:
                    CircularProgressIndicator(color: context.palette.primary)),
          )
        else if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.l10n.noCommentsYet,
                style: TextStyle(
                    fontSize: 13, color: context.palette.textSecondary)),
          )
        else
          ...comments.map((c) => Padding(
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
                style:
                    TextStyle(color: context.palette.textPrimary, fontSize: 13),
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

  Widget _stat(String value, String label, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color ?? context.palette.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: context.palette.textSecondary)),
      ],
    );
  }

  /// Riding score as a fourth stat beside max speed, tier-colored — a number
  /// the rider earned, not just another stat. Only built when
  /// [SharedRideEntity.ridingScore] is non-null (see that getter's doc).
  Widget _scoreStat(int score) {
    final l10n = context.l10n;
    final (color, label) = switch (ridingScoreTier(score)) {
      RidingScoreTier.smooth => (
          context.palette.success,
          l10n.scoreSmoothLabel
        ),
      RidingScoreTier.steady => (
          context.palette.attention,
          l10n.scoreSteadyLabel
        ),
      RidingScoreTier.aggressive => (
          context.palette.danger,
          l10n.scoreAggressiveLabel
        ),
    };
    return _stat('$score', label, color: color);
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: context.palette.border.withValues(alpha: 0.3),
      );
}
