import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
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
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (_) => _NewPostSheet(forumId: forumId),
    ).then((posted) {
      if (posted == true) {
        ref.invalidate(forumPostsProvider(forumId));
        ref.invalidate(forumsForGarageProvider);
      }
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
        data: (_) {
          final posts = ref.watch(forumPostsNotifierProvider(forumId));
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

/// The "New post" sheet's content, as its own [ConsumerStatefulWidget]
/// rather than inline closures over locally-created controllers.
///
/// Root cause of the actual crash here (confirmed from a real stack trace,
/// after two earlier attempts diagnosed the wrong thing — see git history):
/// the previous version created `TextEditingController`s in
/// `_showNewPostSheet` and disposed them in `showModalBottomSheet(...)
/// .then(...)`. That `.then()` fires as soon as `Navigator.pop` is called
/// — NOT once the sheet's exit *animation* has finished rendering — so
/// disposing the controllers there raced the still-playing transition,
/// which was still rebuilding the `TextField`s referencing them:
/// "A TextEditingController was used after being disposed." Everything
/// else in the crash (the `_dependents.isEmpty` InheritedElement assertion,
/// a RenderFlex overflow, "Looking up a deactivated widget's ancestor is
/// unsafe") was a cascading symptom of that one root exception corrupting
/// the tree mid-rebuild, not a separate bug — which is why two earlier
/// fixes aimed at the invalidate/pop *ordering* never actually changed
/// anything: they never touched the disposal code that was the real
/// problem. Owning the controllers as State fields, disposed in
/// State.dispose(), sidesteps the whole class of "when exactly is it safe
/// to dispose" guessing — Flutter guarantees dispose() only runs once this
/// widget is actually gone for good, not merely "popped."
class _NewPostSheet extends ConsumerStatefulWidget {
  final String forumId;
  const _NewPostSheet({required this.forumId});

  @override
  ConsumerState<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends ConsumerState<_NewPostSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty || _submitting) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _submitting = true);
    await ForumRepository().createPost(
      forumId: widget.forumId,
      userId: user.uid,
      userName: user.displayName ?? 'Rider',
      userPhotoUrl: user.photoURL ?? '',
      title: title,
      body: body,
    );
    if (mounted) Navigator.pop(context, true);
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
            controller: _titleController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            style: const TextStyle(color: AppColors.textPrimary),
            maxLines: 4,
            decoration: const InputDecoration(hintText: "What's going on?"),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  final String forumId;
  final ForumPostEntity post;
  const _PostCard({required this.forumId, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => context.push('/forums/$forumId/post/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(photoUrl: post.userPhotoUrl, name: post.userName, radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(post.userName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () =>
                    ref.read(forumPostsNotifierProvider(forumId).notifier).vote(post.id, 1),
                icon: Icon(Icons.arrow_upward,
                    color: post.myVote == 1 ? AppColors.primary : AppColors.textSecondary, size: 18),
              ),
              Text('${post.netScore}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () =>
                    ref.read(forumPostsNotifierProvider(forumId).notifier).vote(post.id, -1),
                icon: Icon(Icons.arrow_downward,
                    color: post.myVote == -1 ? AppColors.danger : AppColors.textSecondary, size: 18),
              ),
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
