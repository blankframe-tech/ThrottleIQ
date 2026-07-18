import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../providers/forum_providers.dart';

/// Post list for a single forum, with a "New post" FAB.
class ForumThreadScreen extends ConsumerWidget {
  final String forumId;
  const ForumThreadScreen({super.key, required this.forumId});

  Future<void> _toggleFollow(BuildContext context, WidgetRef ref, bool isFollowing) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    if (isFollowing) {
      await ForumRepository().unfollowForum(forumId, uid);
    } else {
      await ForumRepository().followForum(forumId, uid);
    }
    if (!context.mounted) return;
    ref.invalidate(forumFollowingProvider(forumId));
    ref.invalidate(forumsForGarageProvider);
  }

  void _showNewPostSheet(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.paddingMd,
            right: AppDimensions.paddingMd,
            top: AppDimensions.paddingMd,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppDimensions.paddingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New post',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyController,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 4,
                decoration: const InputDecoration(hintText: "What's going on?"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final title = titleController.text.trim();
                  final body = bodyController.text.trim();
                  if (title.isEmpty || body.isEmpty) return;
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;

                  await ForumRepository().createPost(
                    forumId: forumId,
                    userId: user.uid,
                    userName: user.displayName ?? 'Rider',
                    userPhotoUrl: user.photoURL ?? '',
                    title: title,
                    body: body,
                  );
                  ref.invalidate(forumPostsProvider(forumId));
                  ref.invalidate(forumsForGarageProvider);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('Post', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      titleController.dispose();
      bodyController.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forumAsync = ref.watch(forumByIdProvider(forumId));
    final postsAsync = ref.watch(forumPostsProvider(forumId));
    final followingAsync = ref.watch(forumFollowingProvider(forumId));
    final isFollowing = followingAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(forumAsync.valueOrNull?.displayName ?? 'Forum'),
        actions: [
          IconButton(
            icon: Icon(isFollowing ? Icons.notifications_active : Icons.notifications_none),
            tooltip: isFollowing ? 'Unfollow' : 'Follow',
            onPressed: () => _toggleFollow(context, ref, isFollowing),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewPostSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New post', style: TextStyle(color: Colors.white)),
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined, size: 64, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text('No posts yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Be the first to ask a question or share something.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(forumPostsProvider(forumId).future),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _PostCard(forumId: forumId, post: posts[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String forumId;
  final ForumPostEntity post;
  const _PostCard({required this.forumId, required this.post});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/forums/$forumId/post/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(post.userName, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              const Spacer(),
              const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${post.replyCount}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
