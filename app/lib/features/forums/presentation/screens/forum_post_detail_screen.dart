import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/entities/forum_reply_entity.dart';
import '../providers/forum_providers.dart';

/// Post body + replies list + reply composer.
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
    setState(() => _loading = true);
    try {
      final post = await ForumRepository().getPost(forumId: widget.forumId, postId: widget.postId);
      final replies = await ForumRepository().getReplies(forumId: widget.forumId, postId: widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _replies = replies;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      ref
          .read(forumPostsNotifierProvider(widget.forumId).notifier)
          .incrementReplyCount(widget.postId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post reply: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _post == null
              ? const Center(
                  child: Text('Post not found', style: TextStyle(color: AppColors.textSecondary)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppDimensions.paddingMd),
                        children: [
                          _buildPostHeader(_post!),
                          const SizedBox(height: 20),
                          Container(height: 1, color: AppColors.border),
                          const SizedBox(height: 16),
                          Text(
                            '${_replies.length} ${_replies.length == 1 ? 'reply' : 'replies'}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          if (_replies.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No replies yet — be the first to help out.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            )
                          else
                            for (final reply in _replies) ...[
                              _buildReply(reply),
                              const SizedBox(height: 12),
                            ],
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.border),
                    _buildComposer(),
                  ],
                ),
    );
  }

  Widget _buildPostHeader(ForumPostEntity post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            UserAvatar(photoUrl: post.userPhotoUrl, name: post.userName, radius: 12),
            const SizedBox(width: 8),
            Text(
              post.userName,
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          post.body,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildReply(ForumReplyEntity reply) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(photoUrl: reply.userPhotoUrl, name: reply.userName, radius: 11),
              const SizedBox(width: 8),
              Text(
                reply.userName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(reply.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Write a reply...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              onSubmitted: (_) => _submitReply(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.primary),
            onPressed: _submitReply,
          ),
        ],
      ),
    );
  }
}
