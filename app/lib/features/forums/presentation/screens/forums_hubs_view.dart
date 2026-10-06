import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/slugify.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_entity.dart';
import '../../domain/forum_author_bike.dart';
import '../../domain/forum_directory.dart';
import '../providers/forum_providers.dart';
import '../widgets/forum_picker_sheet.dart';
import '../widgets/forum_topic_style.dart';

/// The Hubs lens: the rider's garage hubs, brand paddocks, topic boards and
/// rider clubs. Search lives in the Social AppBar ([onOpenSearch]) — this
/// view only offers a shortcut into it, not a second search box.
class ForumsHubsView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSearch;
  const ForumsHubsView({super.key, this.onOpenSearch});

  @override
  ConsumerState<ForumsHubsView> createState() => _ForumsHubsViewState();
}

class _ForumsHubsViewState extends ConsumerState<ForumsHubsView> {
  // The brand/topic slug currently being resolved (getOrCreateForum can be a
  // multi-second Firestore transaction on first open) — null when nothing is
  // in flight. Tracking *which* entry, not just a bool, lets the tapped card
  // itself show a spinner (issues §54: a tapped row that only went inert
  // "reads as broken rather than loading").
  String? _resolving;

  Future<void> _resolveAndOpen(String slug, Future<ForumEntity> Function() resolve) async {
    if (_resolving != null) return;
    setState(() => _resolving = slug);
    try {
      final forum = await resolve();
      if (!mounted) return;
      context.push('/forums/${forum.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenForum(e))),
      );
    } finally {
      if (mounted) setState(() => _resolving = null);
    }
  }

  Future<void> _createClub() async {
    await context.push('/forums/create');
    // A forum created on that screen should show up here on the way back
    // without needing a pull-to-refresh.
    if (mounted) ref.invalidate(customForumsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(directoryForumStatsProvider).valueOrNull ?? const {};

    return RefreshIndicator(
      color: context.palette.primary,
      onRefresh: () async {
        ref.invalidate(directoryForumStatsProvider);
        ref.invalidate(customForumsProvider);
        await refreshGarageForums(ref);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMd, 4, AppDimensions.paddingMd, AppDimensions.paddingLg),
        children: [
          _SearchShortcut(onTap: widget.onOpenSearch),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('hubs_start_discussion'),
                  onPressed: () => showForumPickerSheet(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(context.l10n.startDiscussion, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createClub,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text(context.l10n.createRiderClub, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.yourGarageHubs),
          const SizedBox(height: 10),
          const _GarageHubs(),
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.brandPaddocks),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kBrandPaddocks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final paddock = kBrandPaddocks[i];
                return _BrandPaddockCard(
                  paddock: paddock,
                  forum: stats[paddock.slug],
                  resolving: _resolving == paddock.slug,
                  onTap: () => _resolveAndOpen(
                    paddock.slug,
                    () => ForumRepository().getOrCreateForum(brand: paddock.brand),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.topicBoards),
          const SizedBox(height: 10),
          _TopicBento(
            stats: stats,
            resolving: _resolving,
            onTap: (board) => _resolveAndOpen(
              board.slug,
              () => ForumRepository().getOrCreateGeneralForum(topic: board.topic),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SectionTitle(context.l10n.communityClubs)),
              TextButton.icon(
                onPressed: _createClub,
                icon: Icon(Icons.add, size: 18, color: context.palette.primary),
                label: Text(context.l10n.create, style: TextStyle(color: context.palette.primary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const _RiderClubs(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
      );
}

class _SearchShortcut extends StatelessWidget {
  final VoidCallback? onTap;
  const _SearchShortcut({this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox.shrink();
    return Material(
      color: context.palette.surfaceVariant,
      borderRadius: BorderRadius.circular(context.shape.radiusLg),
      child: InkWell(
        key: const Key('hubs_search'),
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: context.palette.textTertiary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.l10n.searchForumsHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.textTertiary, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your garage" hero cards — one per garage bike model forum.
class _GarageHubs extends ConsumerWidget {
  const _GarageHubs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forumsAsync = ref.watch(forumsForGarageProvider);
    final bikes = ref.watch(garageProvider).valueOrNull ?? const <BikeEntity>[];

    return forumsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(forumsForGarageProvider)),
      data: (forums) {
        if (forums.isEmpty) return const _GarageEmptyBanner();
        return SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: forums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final forum = forums[i];
              final bike = bikeForForum(forum.id, bikes);
              final width = MediaQuery.of(context).size.width -
                  AppDimensions.paddingMd * 2 -
                  (forums.length > 1 ? 36 : 0);
              return SizedBox(
                width: width,
                child: _GarageHeroCard(forum: forum, bike: bike),
              );
            },
          ),
        );
      },
    );
  }
}

/// The garage bike behind a model forum — active bike first if several
/// share the forum.
BikeEntity? bikeForForum(String forumId, List<BikeEntity> bikes) {
  final matches = [
    for (final b in bikes)
      if (b.model.trim().isNotEmpty && bikeForumSlug(b.brand, model: b.model) == forumId) b,
  ];
  if (matches.isEmpty) return null;
  return matches.where((b) => b.isActive).firstOrNull ?? matches.first;
}

class _GarageEmptyBanner extends StatelessWidget {
  const _GarageEmptyBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.garage_outlined, size: 32, color: context.palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.garageHubEmpty,
                  style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/home/profile'),
                  child: Text(context.l10n.openGarage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GarageHeroCard extends ConsumerWidget {
  final ForumEntity forum;
  final BikeEntity? bike;
  const _GarageHeroCard({required this.forum, required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref.watch(forumFollowingProvider(forum.id)).valueOrNull ?? false;
    final accent = bike?.color ?? context.palette.primary;
    final odometer = bike == null ? null : formatOdometerKm(bike!.currentOdometerKm);

    return Container(
      key: Key('garage_hub_${forum.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.shape.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.palette.ink, Color.lerp(context.palette.ink, accent, 0.45)!],
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.two_wheeler, color: context.palette.onInk, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bike?.displayName ?? forum.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: context.palette.onInk),
                ),
              ),
              IconButton(
                tooltip: isFollowing ? context.l10n.unfollow : context.l10n.follow,
                onPressed: () => setForumFollowing(context, ref, forum.id, follow: !isFollowing),
                icon: Icon(
                  isFollowing ? Icons.notifications_active : Icons.notifications_none,
                  color: context.palette.onInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (odometer != null) odometer,
              context.l10n.forumThreadsCount(forum.postCount),
              if (isFollowing) context.l10n.following,
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: context.palette.onInkMuted),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.palette.onInk,
                    foregroundColor: context.palette.ink,
                  ),
                  onPressed: () => openForumComposer(context, forum.id),
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: Text(context.l10n.askOwners, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.onInk,
                    side: BorderSide(color: context.palette.onInkMuted),
                  ),
                  onPressed: () => context.push('/forums/${forum.id}'),
                  child: Text(context.l10n.browseModelBoard, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandPaddockCard extends StatelessWidget {
  final BrandPaddock paddock;
  final ForumEntity? forum;
  final bool resolving;
  final VoidCallback onTap;

  const _BrandPaddockCard({
    required this.paddock,
    required this.forum,
    required this.resolving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(paddock.accent);
    return SizedBox(
      width: 132,
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        child: InkWell(
          key: Key('paddock_${paddock.slug}'),
          borderRadius: BorderRadius.circular(context.shape.radiusLg),
          onTap: resolving ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.shape.radiusLg),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, width: 32, color: accent),
                const SizedBox(height: 10),
                Text(
                  paddock.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: context.palette.textPrimary),
                ),
                const Spacer(),
                if (resolving)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  )
                else
                  Text(
                    forum == null
                        ? context.l10n.openPaddock
                        : context.l10n.forumMembers(forum!.followerCount),
                    style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-column bento of topic boards: the four featured clusters as tall
/// cards with a blurb, the rest compact.
class _TopicBento extends StatelessWidget {
  final Map<String, ForumEntity> stats;
  final String? resolving;
  final void Function(TopicBoard) onTap;

  const _TopicBento({required this.stats, required this.resolving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const boards = TopicBoard.values;
    final rows = <Widget>[];
    for (var i = 0; i < boards.length; i += 2) {
      final pair = boards.sublist(i, i + 2 > boards.length ? boards.length : i + 2);
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < pair.length; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(
                child: _TopicTile(
                  board: pair[j],
                  forum: stats[pair[j].slug],
                  resolving: resolving == pair[j].slug,
                  onTap: resolving == null ? () => onTap(pair[j]) : null,
                ),
              ),
            ],
            if (pair.length == 1) const Expanded(child: SizedBox()),
          ],
        ),
      ));
      rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class _TopicTile extends StatelessWidget {
  final TopicBoard board;
  final ForumEntity? forum;
  final bool resolving;
  final VoidCallback? onTap;

  const _TopicTile({
    required this.board,
    required this.forum,
    required this.resolving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(board.accent);
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(context.shape.radiusLg),
      child: InkWell(
        key: Key('topic_${board.slug}'),
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(board.featured ? 14 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: board.featured ? 36 : 28,
                    height: board.featured ? 36 : 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(topicBoardIcon(board),
                        color: accent, size: board.featured ? 20 : 16),
                  ),
                  const Spacer(),
                  if (resolving)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                topicBoardTitle(context.l10n, board),
                style: TextStyle(
                  fontSize: board.featured ? 14 : 13,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              if (board.featured) ...[
                const SizedBox(height: 2),
                Text(
                  topicBoardBlurb(context.l10n, board),
                  style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
                ),
              ],
              if (forum != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.l10n.forumThreadsCount(forum!.postCount),
                  style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderClubs extends ConsumerWidget {
  const _RiderClubs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(customForumsProvider);
    final user = ref.watch(currentUserProvider);
    return clubsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(customForumsProvider)),
      data: (clubs) {
        if (clubs.isEmpty) {
          return Text(
            context.l10n.noRiderMadeForums,
            style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
          );
        }
        return Column(
          children: [
            for (final club in clubs) ...[
              AppCard(
                onTap: () => context.push('/forums/${club.id}'),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.palette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.groups_outlined, color: context.palette.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  club.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: context.palette.textPrimary),
                                ),
                              ),
                              // The rider's own role here, not admin reach —
                              // the admin can moderate every club but
                              // maintains none of them.
                              if (user != null &&
                                  (club.createdBy == user.uid ||
                                      club.maintainerIds.contains(user.uid))) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.shield_outlined,
                                    size: 14, color: context.palette.success),
                                const SizedBox(width: 2),
                                Text(context.l10n.clubMaintainerBadge,
                                    style: TextStyle(
                                        fontSize: 11, color: context.palette.success)),
                              ],
                            ],
                          ),
                          if ((club.description ?? '').isNotEmpty)
                            Text(
                              club.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: context.palette.textSecondary),
                            ),
                          Text(
                            context.l10n.postsFollowers(club.postCount, club.followerCount),
                            style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.palette.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
