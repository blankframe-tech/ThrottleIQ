import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/forum_directory.dart';
import '../providers/forum_providers.dart';
import 'forum_topic_style.dart';

/// Opens a forum's thread with the new-post sheet already up, optionally
/// carrying an [attachment] (a shared ride or maintenance visit).
void openForumComposer(BuildContext context, String forumId, {ForumAttachment? attachment}) {
  context.push('/forums/$forumId?compose=1', extra: attachment);
}

/// "Where should this go?" — the rider's garage and followed forums first
/// (already known to Pulse, so no extra reads), then the topic boards.
/// Picking one opens that forum's composer via [openForumComposer].
///
/// Used by "Start a discussion" and by "Share to forum" on a ride summary or
/// maintenance visit.
Future<void> showForumPickerSheet(
  BuildContext context, {
  ForumAttachment? attachment,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(context.shape.radiusLg)),
    ),
    builder: (_) => _ForumPickerSheet(attachment: attachment, title: title),
  );
}

class _ForumPickerSheet extends ConsumerStatefulWidget {
  final ForumAttachment? attachment;
  final String? title;
  const _ForumPickerSheet({this.attachment, this.title});

  @override
  ConsumerState<_ForumPickerSheet> createState() => _ForumPickerSheetState();
}

class _ForumPickerSheetState extends ConsumerState<_ForumPickerSheet> {
  String? _resolving;

  void _pick(String forumId) {
    // Pop first, then navigate from the root context once the sheet's route
    // is gone — same pop-then-push hazard bike_detail_screen.dart documents.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/forums/$forumId?compose=1', extra: widget.attachment);
  }

  Future<void> _pickTopic(TopicBoard board) async {
    if (_resolving != null) return;
    setState(() => _resolving = board.slug);
    try {
      final forum = await ForumRepository().getOrCreateGeneralForum(topic: board.topic);
      if (!mounted) return;
      _pick(forum.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolving = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenForum(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(pulseSourcesProvider);
    final sources = sourcesAsync.valueOrNull ?? PulseSources.empty;
    final attachment = widget.attachment;
    // A maintenance visit most naturally belongs on the Wrench Bench, so it
    // leads the topic list for that case.
    final boards = [
      ...TopicBoard.values,
    ]..sort((a, b) {
        if (attachment?.kind == ForumAttachmentKind.maintenance) {
          if (a == TopicBoard.wrenchBench) return -1;
          if (b == TopicBoard.wrenchBench) return 1;
        }
        return a.index.compareTo(b.index);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          Text(
            widget.title ?? context.l10n.startDiscussionPickForum,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
          ),
          const SizedBox(height: 12),
          if (sourcesAsync.isLoading)
            Center(child: CircularProgressIndicator(color: context.palette.primary))
          else if (sources.forumIds.isNotEmpty) ...[
            for (final id in sources.forumIds)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  sources.garageForumIds.contains(id) ? Icons.two_wheeler : Icons.forum_outlined,
                  color: context.palette.primary,
                ),
                title: Text(sources.names[id] ?? id,
                    style: TextStyle(color: context.palette.textPrimary)),
                trailing: Icon(Icons.chevron_right, color: context.palette.textTertiary),
                onTap: _resolving == null ? () => _pick(id) : null,
              ),
            Divider(color: context.palette.border),
          ],
          for (final board in boards)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(topicBoardIcon(board), color: Color(board.accent)),
              title: Text(topicBoardTitle(context.l10n, board),
                  style: TextStyle(color: context.palette.textPrimary)),
              trailing: _resolving == board.slug
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.palette.primary),
                    )
                  : Icon(Icons.chevron_right, color: context.palette.textTertiary),
              onTap: _resolving == null ? () => _pickTopic(board) : null,
            ),
        ],
      ),
    );
  }
}
