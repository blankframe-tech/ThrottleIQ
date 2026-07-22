import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
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
  bool _resolving = false;

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
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openBrandForum(String brand) async {
    final trimmed = brand.trim();
    if (trimmed.isEmpty || _resolving) return;
    setState(() => _resolving = true);
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
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _openGeneralForum(String topic) async {
    if (_resolving) return;
    setState(() => _resolving = true);
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
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final garageForumsAsync = ref.watch(forumsForGarageProvider);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        const Text(
          'Your bikes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        garageForumsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
          data: (forums) {
            if (forums.isEmpty) {
              return const Text(
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
        const Text(
          'Topics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _generalTopics.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _DiscoverRow(
                  icon: Icons.topic_outlined,
                  label: _generalTopics[i],
                  enabled: !_resolving,
                  onTap: () => _openGeneralForum(_generalTopics[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Find a forum',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search a brand, e.g. Yamaha',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                onSubmitted: _openBrandForum,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.primary),
              onPressed: _resolving ? null : () => _openBrandForum(_searchController.text),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _popularBrands.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _DiscoverRow(
                  icon: Icons.two_wheeler,
                  label: _popularBrands[i],
                  enabled: !_resolving,
                  onTap: () => _openBrandForum(_popularBrands[i]),
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
  final VoidCallback onTap;
  const _DiscoverRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.forum_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forum.displayName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  '${forum.postCount} posts · ${forum.followerCount} followers',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
