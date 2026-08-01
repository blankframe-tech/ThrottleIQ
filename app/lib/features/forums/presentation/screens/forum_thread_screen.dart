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
import '../../domain/forum_permissions.dart';
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
    final user = ref.watch(currentUserProvider);
    final forum = forumAsync.valueOrNull;
    final showMaintainers = forum != null &&
        canManageMaintainers(forum: forum, uid: user?.uid, email: user?.email);

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
          if (showMaintainers)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Manage maintainers',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
                ),
                builder: (_) => _MaintainersSheet(forumId: forumId),
              ),
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
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: AppColors.danger))),
        data: (_) {
          final posts = ref.watch(forumPostsNotifierProvider(forumId));
          if (posts.isEmpty) {
            return Center(
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
          Text(
            'New post',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            style: TextStyle(color: AppColors.textPrimary),
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

  Future<void> _castVote(BuildContext context, WidgetRef ref, String postId, int value) async {
    try {
      await ref.read(forumPostsNotifierProvider(forumId).notifier).vote(postId, value);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't record your vote — check your connection and try again.")),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete post?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This removes the post and its replies from the forum. It cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ForumRepository().deletePost(forumId: forumId, postId: post.id);
      if (!context.mounted) return;
      ref.invalidate(forumPostsProvider(forumId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final forum = ref.watch(forumByIdProvider(forumId)).valueOrNull;
    // Riders can always remove their own post; moderating *other* people's
    // posts additionally needs the admin/creator/maintainer check.
    final canDelete = post.userId == user?.uid ||
        (forum != null &&
            canModerate(forum: forum, uid: user?.uid, email: user?.email));

    return AppCard(
      onTap: () => context.push('/forums/$forumId/post/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Opaque + its own tight (non-Expanded) tap target so tapping
              // the author's name/avatar opens their profile instead of
              // falling through to the card's own onTap (post detail) —
              // same nested-GestureDetector hit-testing gotcha fixed in
              // garage_screen.dart's maintenance link; see that fix's doc
              // comment for the mechanics. Doubles as "add people from
              // forum posts": the profile screen has the Follow button.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/profile/${post.userId}'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(photoUrl: post.userPhotoUrl, name: post.userName, radius: 14),
                    const SizedBox(width: 8),
                    Text(post.userName,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              const Spacer(),
              if (canDelete)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Delete post',
                  onPressed: () => _confirmDelete(context, ref),
                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _castVote(context, ref, post.id, 1),
                icon: Icon(Icons.arrow_upward,
                    color: post.myVote == 1 ? AppColors.primary : AppColors.textSecondary, size: 18),
              ),
              Text('${post.netScore}',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _castVote(context, ref, post.id, -1),
                icon: Icon(Icons.arrow_downward,
                    color: post.myVote == -1 ? AppColors.danger : AppColors.textSecondary, size: 18),
              ),
              const Spacer(),
              Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${post.replyCount}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Maintainer management for a rider-created forum.
///
/// Deliberately UID-based rather than a rider search: for the closed beta the
/// creator knows the handful of people they're appointing, and a search
/// surface would mean a user-directory query this feature doesn't otherwise
/// need. The `_RiderSearchSheet` in social_screen.dart is the natural
/// upgrade path when this outgrows pasting UIDs.
class _MaintainersSheet extends ConsumerStatefulWidget {
  final String forumId;
  const _MaintainersSheet({required this.forumId});

  @override
  ConsumerState<_MaintainersSheet> createState() => _MaintainersSheetState();
}

class _MaintainersSheetState extends ConsumerState<_MaintainersSheet> {
  final _uidCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(forumByIdProvider(widget.forumId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update maintainers: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final uid = _uidCtrl.text.trim();
    if (uid.isEmpty) return;
    await _run(() => ForumRepository().addMaintainer(widget.forumId, uid));
    if (mounted) _uidCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final forum = ref.watch(forumByIdProvider(widget.forumId)).valueOrNull;
    final maintainers = forum?.maintainerIds ?? const <String>[];

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: AppDimensions.paddingMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.paddingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maintainers',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Maintainers can delete posts and replies in this forum.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (maintainers.isEmpty)
            Text(
              'No maintainers yet.',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            )
          else
            for (final uid in maintainers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uid,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Remove',
                      onPressed: _busy
                          ? null
                          : () => _run(() =>
                              ForumRepository().removeMaintainer(widget.forumId, uid)),
                      icon: Icon(Icons.close, size: 18, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _uidCtrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Add by rider UID',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _busy ? null : _add,
                icon: Icon(Icons.add, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
