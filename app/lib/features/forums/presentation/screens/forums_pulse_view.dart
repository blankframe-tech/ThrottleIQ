import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/extensions/datetime_extensions.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_card.dart';
import '../widgets/forum_post_images.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/forum_pulse.dart';
import '../providers/forum_bookmarks_provider.dart';
import '../providers/forum_providers.dart';
import '../widgets/forum_post_badges.dart';

String pulseFilterLabel(AppLocalizations l10n, PulseFilter filter) {
  switch (filter) {
    case PulseFilter.all:
      return l10n.pulseFilterAll;
    case PulseFilter.myBikes:
      return l10n.pulseFilterMyBikes;
    case PulseFilter.help:
      return l10n.pulseFilterHelp;
    case PulseFilter.diy:
      return l10n.pulseFilterDiy;
    case PulseFilter.mostVoted:
      return l10n.pulseFilterMostVoted;
    case PulseFilter.saved:
      return l10n.pulseFilterSaved;
  }
}

/// The Pulse lens: recent discussions across the rider's garage and
/// followed forums, filterable by chip. See `forumsPulseFeedProvider` for
/// the read budget.
class ForumsPulseView extends ConsumerStatefulWidget {
  /// Switches the Forums tab to the Hubs lens (from the empty state).
  final VoidCallback onExploreHubs;
  const ForumsPulseView({super.key, required this.onExploreHubs});

  @override
  ConsumerState<ForumsPulseView> createState() => _ForumsPulseViewState();
}

class _ForumsPulseViewState extends ConsumerState<ForumsPulseView> {
  PulseFilter _filter = PulseFilter.all;

  @override
  Widget build(BuildContext context) {
    final firstAsync = ref.watch(forumsPulseFeedProvider);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMd, vertical: 6),
            children: [
              for (final f in PulseFilter.values) ...[
                ChoiceChip(
                  key: Key('pulse_filter_${f.name}'),
                  label: Text(pulseFilterLabel(context.l10n, f)),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: context.palette.primary.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _filter == f ? context.palette.primary : context.palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: _filter == PulseFilter.saved
              ? const _SavedList()
              : firstAsync.when(
                  loading: () =>
                      Center(child: CircularProgressIndicator(color: context.palette.primary)),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(pulseSourcesProvider),
                  ),
                  data: (first) => _buildFeed(first),
                ),
        ),
      ],
    );
  }

  Widget _buildFeed(PulseFirstPage first) {
    final all = ref.watch(pulseFeedNotifierProvider);
    final notifier = ref.read(pulseFeedNotifierProvider.notifier);

    Future<void> refresh() async {
      ref.invalidate(pulseSourcesProvider);
      await ref.read(forumsPulseFeedProvider.future);
    }

    if (first.sources.forumIds.isEmpty) {
      return _PulseEmpty(onExploreHubs: widget.onExploreHubs);
    }
    final posts = filterPulsePosts(all, _filter, garageForumIds: first.sources.garageForumIds);
    final showMore = notifier.hasMore && _filter != PulseFilter.mostVoted;

    return RefreshIndicator(
      color: context.palette.primary,
      onRefresh: refresh,
      child: posts.isEmpty && !showMore
          ? ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              children: [
                const SizedBox(height: 48),
                Icon(Icons.filter_alt_off_outlined, size: 48, color: context.palette.textTertiary),
                const SizedBox(height: 12),
                Text(
                  all.isEmpty ? context.l10n.pulseNoPostsYet : context.l10n.pulseNoMatches,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 4,
                  AppDimensions.paddingMd, AppDimensions.paddingLg),
              itemCount: posts.length + (showMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                if (i == posts.length) {
                  return Center(
                    child: notifier.isLoadingMore
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(color: context.palette.primary),
                          )
                        : OutlinedButton(
                            onPressed: () async {
                              try {
                                await notifier.loadMore();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(mapFirestoreError(e, context.l10n))),
                                );
                              }
                            },
                            child: Text(context.l10n.loadMore),
                          ),
                  );
                }
                final post = posts[i];
                return PulsePostCard(
                  post: post,
                  originName: first.sources.names[post.forumId] ?? '',
                );
              },
            ),
    );
  }
}

class _PulseEmpty extends StatelessWidget {
  final VoidCallback onExploreHubs;
  const _PulseEmpty({required this.onExploreHubs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, size: 56, color: context.palette.textTertiary),
            const SizedBox(height: 12),
            Text(
              context.l10n.pulseEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.pulseEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onExploreHubs,
              icon: const Icon(Icons.explore_outlined),
              label: Text(context.l10n.pulseExploreHubs),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved posts — local snapshots, so this list costs no reads.
class _SavedList extends ConsumerWidget {
  const _SavedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(forumBookmarksProvider);
    if (saved.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 48, color: context.palette.textTertiary),
              const SizedBox(height: 12),
              Text(
                context.l10n.pulseNoSaved,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMd, 4, AppDimensions.paddingMd, AppDimensions.paddingLg),
      itemCount: saved.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final b = saved[i];
        return AppCard(
          onTap: () => context.push('/forums/${b.forumId}/post/${b.postId}'),
          child: Row(
            children: [
              Icon(forumPostTypeIcon(b.postType), color: context.palette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary)),
                    if (b.forumName.isNotEmpty)
                      Text(b.forumName,
                          style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.unsavePost,
                icon: Icon(Icons.bookmark, color: context.palette.primary),
                onPressed: () => ref.read(forumBookmarksProvider.notifier).removeKey(b.key),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One Pulse discussion: origin forum, post tag, title + snippet, author
/// with their bike, score, replies, age, and a bookmark.
class PulsePostCard extends ConsumerWidget {
  final ForumPostEntity post;
  final String originName;
  const PulsePostCard({super.key, required this.post, required this.originName});

  Future<void> _vote(BuildContext context, WidgetRef ref, int value) async {
    try {
      await ref.read(pulseFeedNotifierProvider.notifier).vote(post.id, value);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldntRecordVoteCheck)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(forumBookmarksProvider
        .select((list) => list.any((b) => b.forumId == post.forumId && b.postId == post.id)));

    return AppCard(
      key: Key('pulse_post_${post.id}'),
      onTap: () => context.push('/forums/${post.forumId}/post/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (originName.isNotEmpty)
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/forums/${post.forumId}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(context.shape.radiusSm),
                      ),
                      child: Text(
                        originName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textSecondary),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              ForumPostTypeTag(post: post),
              const Spacer(),
              Text(post.createdAt.timeAgo,
                  style: TextStyle(fontSize: 11, color: context.palette.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            post.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            ForumPostImages(urls: post.imageUrls, compact: true),
          ],
          if (post.attachment != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  post.attachment!.kind == ForumAttachmentKind.ride
                      ? Icons.route
                      : Icons.build_outlined,
                  size: 14,
                  color: context.palette.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.attachment!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              UserAvatar(photoUrl: post.userPhotoUrl, name: post.userName, radius: 11),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.palette.textPrimary)),
                    if (post.authorBike != null) AuthorBikeBadge(bike: post.authorBike!),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: context.l10n.upvote,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => _vote(context, ref, 1),
                icon: Icon(Icons.arrow_upward,
                    size: 17,
                    color: post.myVote == 1
                        ? context.palette.primary
                        : context.palette.textSecondary),
              ),
              Text('${post.netScore}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary)),
              IconButton(
                tooltip: context.l10n.downvote,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => _vote(context, ref, -1),
                icon: Icon(Icons.arrow_downward,
                    size: 17,
                    color: post.myVote == -1
                        ? context.palette.danger
                        : context.palette.textSecondary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chat_bubble_outline, size: 15, color: context.palette.textSecondary),
              const SizedBox(width: 3),
              Text('${post.replyCount}',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
              IconButton(
                tooltip: saved ? context.l10n.unsavePost : context.l10n.savePost,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => ref
                    .read(forumBookmarksProvider.notifier)
                    .toggle(post, forumName: originName),
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 19,
                    color: saved ? context.palette.primary : context.palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
