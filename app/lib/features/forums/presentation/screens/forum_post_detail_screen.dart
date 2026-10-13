import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/entities/forum_reply_entity.dart';
import '../../domain/forum_solution.dart';
import '../providers/forum_bookmarks_provider.dart';
import '../providers/forum_providers.dart';
import '../widgets/forum_post_badges.dart';
import '../widgets/forum_post_images.dart';
import '../../../../core/i18n/l10n_context.dart';

/// Post body + replies list + reply composer.
///
/// On a troubleshooting post the author can mark it solved and accept one
/// reply as the solution; the accepted reply is pinned to the top of the
/// replies, highlighted (see `forum_solution.dart`).
class ForumPostDetailScreen extends ConsumerStatefulWidget {
  final String forumId;
  final String postId;
  const ForumPostDetailScreen({super.key, required this.forumId, required this.postId});

  @override
  ConsumerState<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends ConsumerState<ForumPostDetailScreen> {
  final _replyController = TextEditingController();
  bool _loading = true;
  bool _updatingSolution = false;
  Object? _loadError;
  ForumPostEntity? _post;
  List<ForumReplyEntity> _replies = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final post = await ForumRepository().getPost(forumId: widget.forumId, postId: widget.postId);
      final replies = await ForumRepository().getReplies(forumId: widget.forumId, postId: widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _replies = replies;
        _loading = false;
      });
    } catch (e, st) {
      // Used to be a bare catch that showed "Post not found" for any
      // failure, offline included.
      reportNonFatal(e, st, reason: 'ForumPostDetailScreen._load');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  /// Patches the post in whichever live lists hold it — only those that
  /// already exist, so this never spins up (and pays for) a list nobody is
  /// showing.
  void _patchLists(ForumPostEntity post) {
    final thread = forumPostsNotifierProvider(widget.forumId);
    if (ref.exists(thread)) ref.read(thread.notifier).patchPost(post);
    if (ref.exists(pulseFeedNotifierProvider)) {
      ref.read(pulseFeedNotifierProvider.notifier).patchPost(post);
    }
  }

  Future<void> _applySolution(({bool isSolved, String? solutionReplyId}) next) async {
    final post = _post;
    if (post == null || _updatingSolution) return;
    final updated = post.copyWith(isSolved: next.isSolved, solutionReplyId: next.solutionReplyId);
    setState(() {
      _updatingSolution = true;
      _post = updated;
    });
    try {
      await ForumRepository().setPostSolution(
        forumId: widget.forumId,
        postId: widget.postId,
        isSolved: next.isSolved,
        solutionReplyId: next.solutionReplyId,
      );
      if (!mounted) return;
      _patchLists(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = post);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.forumCouldNotUpdateSolution(e))),
      );
    } finally {
      if (mounted) setState(() => _updatingSolution = false);
    }
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _replyController.clear();
    try {
      await ForumRepository().addReply(
        forumId: widget.forumId,
        postId: widget.postId,
        userId: user.uid,
        userName: user.displayName ?? 'Rider',
        userPhotoUrl: user.photoURL ?? '',
        body: text,
      );
      await _load();
      if (!mounted) return;
      final thread = forumPostsNotifierProvider(widget.forumId);
      if (ref.exists(thread)) ref.read(thread.notifier).incrementReplyCount(widget.postId);
      if (ref.exists(pulseFeedNotifierProvider)) {
        ref.read(pulseFeedNotifierProvider.notifier).incrementReplyCount(widget.postId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedPostReply(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final saved = post != null &&
        ref.watch(forumBookmarksProvider
            .select((list) => list.any((b) => b.forumId == post.forumId && b.postId == post.id)));
    final forumName = ref.watch(forumByIdProvider(widget.forumId)).valueOrNull?.displayName ?? '';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(context.l10n.post),
        actions: [
          if (post != null)
            IconButton(
              tooltip: saved ? context.l10n.unsavePost : context.l10n.savePost,
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () =>
                  ref.read(forumBookmarksProvider.notifier).toggle(post, forumName: forumName),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.palette.primary))
          : _loadError != null
              ? ErrorView(error: _loadError!, onRetry: _load)
              : post == null
                  ? Center(
                      child: Text(context.l10n.postNotFound,
                          style: TextStyle(color: context.palette.textSecondary)))
                  : _buildBody(post),
    );
  }

  Widget _buildBody(ForumPostEntity post) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final isAuthorOfTroubleshoot = canMarkSolution(post, uid);
    final ordered = orderRepliesWithSolutionFirst(_replies, post.solutionReplyId);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            children: [
              _buildPostHeader(post, uid),
              if (isAuthorOfTroubleshoot) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('toggle_solved'),
                    onPressed: _updatingSolution
                        ? null
                        : () => _applySolution(toggleSolvedFlag(post)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          post.isSolved ? context.palette.textSecondary : context.palette.success,
                      side: BorderSide(
                          color: post.isSolved ? context.palette.border : context.palette.success),
                    ),
                    icon: Icon(post.isSolved ? Icons.replay : Icons.check_circle_outline, size: 18),
                    label: Text(post.isSolved ? context.l10n.forumReopen : context.l10n.forumMarkSolved),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(height: 1, color: context.palette.border),
              const SizedBox(height: 16),
              Text(
                '${_replies.length} ${_replies.length == 1 ? 'reply' : 'replies'}',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
              ),
              const SizedBox(height: 12),
              if (_replies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.l10n.noRepliesYetBe,
                      style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                )
              else
                for (final reply in ordered) ...[
                  _buildReply(
                    reply,
                    isSolution: reply.id == post.solutionReplyId,
                    canAccept: isAuthorOfTroubleshoot,
                    post: post,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
        Container(height: 1, color: context.palette.border),
        _buildComposer(),
      ],
    );
  }

  Widget _buildPostHeader(ForumPostEntity post, String? uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [ForumPostTypeTag(post: post)]),
        if (post.postType != ForumPostType.general) const SizedBox(height: 8),
        Text(
          post.title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/profile/${post.userId}'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(photoUrl: post.userPhotoUrl, name: post.userName, radius: 12),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: TextStyle(fontSize: 13, color: context.palette.textTertiary),
                    ),
                    if (post.authorBike != null) AuthorBikeBadge(bike: post.authorBike!),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          post.body,
          style: TextStyle(fontSize: 14, color: context.palette.textPrimary, height: 1.4),
        ),
        if (post.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          ForumPostImages(urls: post.imageUrls),
        ],
        if (post.attachment != null) ...[
          const SizedBox(height: 12),
          ForumAttachmentCard(
            attachment: post.attachment!,
            viewerIsAuthor: post.userId == uid,
            authorName: post.userName,
          ),
        ],
      ],
    );
  }

  Widget _buildReply(
    ForumReplyEntity reply, {
    required bool isSolution,
    required bool canAccept,
    required ForumPostEntity post,
  }) {
    final success = context.palette.success;
    return Container(
      key: Key('reply_${reply.id}'),
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: isSolution ? success.withValues(alpha: 0.10) : context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(
          color: isSolution ? success : context.palette.border,
          width: isSolution ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSolution) ...[
            Row(
              children: [
                Icon(Icons.verified, size: 16, color: success),
                const SizedBox(width: 4),
                Text(
                  context.l10n.forumAcceptedSolution,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: success),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/profile/${reply.userId}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(photoUrl: reply.userPhotoUrl, name: reply.userName, radius: 11),
                const SizedBox(width: 8),
                Text(
                  reply.userName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(reply.body, style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
          if (canAccept) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('accept_${reply.id}'),
                onPressed: _updatingSolution
                    ? null
                    : () => _applySolution(toggleAcceptedReply(post, reply.id)),
                style: TextButton.styleFrom(
                  foregroundColor: isSolution ? context.palette.textSecondary : success,
                ),
                icon: Icon(isSolution ? Icons.close : Icons.check, size: 16),
                label: Text(isSolution
                    ? context.l10n.forumUnacceptSolution
                    : context.l10n.forumAcceptSolution),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              style: TextStyle(color: context.palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.l10n.writeReply,
                hintStyle: TextStyle(color: context.palette.textTertiary),
              ),
              onSubmitted: (_) => _submitReply(),
            ),
          ),
          IconButton(
            tooltip: context.l10n.send,
            icon: Icon(Icons.send, color: context.palette.primary),
            onPressed: _submitReply,
          ),
        ],
      ),
    );
  }
}
