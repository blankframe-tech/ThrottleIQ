import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_entity.dart';
import '../providers/forum_providers.dart';

/// Forums tab inside SocialScreen: "Your bikes" forums (auto-created from the
/// garage) first, then a simple brand search/discover list to find and
/// follow forums for bikes the rider doesn't own.
class ForumsHomeScreen extends ConsumerStatefulWidget {
  const ForumsHomeScreen({super.key});

  @override
  ConsumerState<ForumsHomeScreen> createState() => _ForumsHomeScreenState();
}

class _ForumsHomeScreenState extends ConsumerState<ForumsHomeScreen> {
  final _searchController = TextEditingController();
  // The brand/topic currently being resolved (getOrCreateForum can be a
  // multi-second Firestore transaction on first open) — null when nothing is
  // in flight. Tracking *which* entry, not just a bool, lets the tapped row
  // itself show a spinner (docs/Issues.md §54: opening a brand forum used to
  // just disable the row with no visible feedback at all, "for a moment it
  // reads as broken rather than loading" — the per-bike tiles above never had
  // this problem because their forum is already resolved before the tile
  // exists to tap).
  String? _resolvingEntry;

  static const _popularBrands = [
    'Yamaha',
    'Honda',
    'Royal Enfield',
    'KTM',
    'Bajaj',
    'TVS',
    'Suzuki',
    'Kawasaki',
    'Hero',
  ];

  static const _generalTopics = [
    'Maintenance',
    'Riding Skills',
    'Two-Strokes',
    'Dirt Bikes',
    'Spark Plug Corner',
    'Engine Rebuild',
    'Mileage Tips',
    'Engine Oil Review',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openBrandForum(String brand) async {
    final trimmed = brand.trim();
    if (trimmed.isEmpty || _resolvingEntry != null) return;
    setState(() => _resolvingEntry = trimmed);
    try {
      final forum = await ForumRepository().getOrCreateForum(brand: trimmed);
      if (!mounted) return;
      context.push('/forums/${forum.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open forum: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolvingEntry = null);
    }
  }

  Future<void> _openGeneralForum(String topic) async {
    if (_resolvingEntry != null) return;
    setState(() => _resolvingEntry = topic);
    try {
      final forum = await ForumRepository().getOrCreateGeneralForum(topic: topic);
      if (!mounted) return;
      context.push('/forums/${forum.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open forum: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolvingEntry = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final garageForumsAsync = ref.watch(forumsForGarageProvider);
    final customForumsAsync = ref.watch(customForumsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        Text(
          'Your bikes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        garageForumsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) =>
              ErrorView(error: e, onRetry: () => ref.invalidate(forumsForGarageProvider)),
          data: (forums) {
            if (forums.isEmpty) {
              return Text(
                'Add a bike to your garage to see its forum here.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final forum in forums) ...[
                  _ForumCard(forum: forum),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Rider forums',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await context.push('/forums/create');
                // A forum created on that screen should show up here on the
                // way back without needing a pull-to-refresh.
                if (context.mounted) ref.invalidate(customForumsProvider);
              },
              icon: Icon(Icons.add, size: 18, color: AppColors.primary),
              label: Text('Create', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        customForumsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) =>
              ErrorView(error: e, onRetry: () => ref.invalidate(customForumsProvider)),
          data: (forums) {
            if (forums.isEmpty) {
              return Text(
                'No rider-made forums yet. Create the first one.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final forum in forums) ...[
                  _ForumCard(forum: forum),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Find a forum',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search a brand, e.g. Yamaha',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                onSubmitted: _openBrandForum,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _resolvingEntry != null &&
                      _resolvingEntry == _searchController.text.trim()
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : Icon(Icons.search, color: AppColors.primary),
              onPressed: _resolvingEntry != null
                  ? null
                  : () => _openBrandForum(_searchController.text),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Brands and topics are both "a forum you don't own your way into" —
        // the same discovery act, so they share one block rather than each
        // getting a top-level section. Brands lead because the search box
        // directly above them searches brands.
        _DiscoverGroup(
          label: 'Brands',
          icon: Icons.two_wheeler,
          entries: _popularBrands,
          resolvingEntry: _resolvingEntry,
          onTap: _openBrandForum,
        ),
        const SizedBox(height: 16),
        _DiscoverGroup(
          label: 'Topics',
          icon: Icons.topic_outlined,
          entries: _generalTopics,
          resolvingEntry: _resolvingEntry,
          onTap: _openGeneralForum,
        ),
      ],
    );
  }
}

/// One labelled group of discovery rows inside "Find a forum".
class _DiscoverGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> entries;
  // The entry currently being resolved (null = nothing in flight). Passed
  // through rather than a plain `enabled` bool so the tapped row can show a
  // spinner instead of just going inert — see _resolvingEntry's doc comment.
  final String? resolvingEntry;
  final void Function(String) onTap;

  const _DiscoverGroup({
    required this.label,
    required this.icon,
    required this.entries,
    required this.resolvingEntry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.border),
                _DiscoverRow(
                  icon: icon,
                  label: entries[i],
                  enabled: resolvingEntry == null,
                  resolving: resolvingEntry == entries[i],
                  onTap: () => onTap(entries[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain tappable list row used for forum discovery (popular brands,
/// general topics) — these forums may not exist yet, so unlike [_ForumCard]
/// there are no post/follower stats to show.
class _DiscoverRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool resolving;
  final VoidCallback onTap;
  const _DiscoverRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.resolving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      trailing: resolving
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            )
          : Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
    );
  }
}

class _ForumCard extends ConsumerWidget {
  final ForumEntity forum;
  const _ForumCard({required this.forum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(forumFollowingProvider(forum.id));
    final isFollowing = followingAsync.valueOrNull ?? false;

    return AppCard(
      onTap: () => context.push('/forums/${forum.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.forum_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forum.displayName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  '${forum.postCount} posts · ${forum.followerCount} followers',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isFollowing ? Icons.notifications_active : Icons.notifications_none,
              color: isFollowing ? AppColors.primary : AppColors.textSecondary,
            ),
            onPressed: () async {
              final uid = ref.read(currentUserProvider)?.uid;
              if (uid == null) return;
              if (isFollowing) {
                await ForumRepository().unfollowForum(forum.id, uid);
              } else {
                await ForumRepository().followForum(forum.id, uid);
              }
              if (!context.mounted) return;
              ref.invalidate(forumFollowingProvider(forum.id));
              ref.invalidate(forumsForGarageProvider);
            },
          ),
        ],
      ),
    );
  }
}
