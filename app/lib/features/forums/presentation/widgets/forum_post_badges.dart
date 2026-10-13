import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/forum_post_entity.dart';

/// The rider-facing name of a post type (the picker in the new-post sheet).
String forumPostTypeLabel(AppLocalizations l10n, ForumPostType type) {
  switch (type) {
    case ForumPostType.troubleshoot:
      return l10n.forumPostTypeTroubleshoot;
    case ForumPostType.diyGuide:
      return l10n.forumPostTypeDiyGuide;
    case ForumPostType.gearReview:
      return l10n.forumPostTypeGearReview;
    case ForumPostType.general:
      return l10n.forumPostTypeGeneral;
  }
}

IconData forumPostTypeIcon(ForumPostType type) {
  switch (type) {
    case ForumPostType.troubleshoot:
      return Icons.build_circle_outlined;
    case ForumPostType.diyGuide:
      return Icons.lightbulb_outline;
    case ForumPostType.gearReview:
      return Icons.star_outline;
    case ForumPostType.general:
      return Icons.chat_bubble_outline;
  }
}

/// Small uppercase pill: `[HELP]` amber, `[SOLVED]` green, `[GUIDE]` blue,
/// `[GEAR]` purple-ish secondary. General posts get no tag.
class ForumPostTypeTag extends StatelessWidget {
  final ForumPostEntity post;
  const ForumPostTypeTag({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final (String label, Color color)? spec = switch (post.postType) {
      ForumPostType.troubleshoot => post.isSolved
          ? (l10n.forumTagSolved, palette.success)
          : (l10n.forumTagHelpNeeded, palette.warning),
      ForumPostType.diyGuide => (l10n.forumTagGuide, palette.primary),
      ForumPostType.gearReview => (l10n.forumTagGear, palette.secondary),
      ForumPostType.general => null,
    };
    if (spec == null) return const SizedBox.shrink();
    final (label, color) = spec;
    return _Pill(
      label: label,
      color: color,
      icon: post.isTroubleshoot && post.isSolved ? Icons.check_circle : null,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.shape.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The author's bike next to their name: "🏍 Yamaha MT-15 · 12,400 km".
class AuthorBikeBadge extends StatelessWidget {
  final String bike;
  const AuthorBikeBadge({super.key, required this.bike});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.two_wheeler, size: 13, color: context.palette.primary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            bike,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A shared ride summary / maintenance visit inside a post.
///
/// The record itself lives in the author's local database, so only the
/// author can open it ([viewerIsAuthor]); everyone else gets the snapshot
/// in a dialog.
class ForumAttachmentCard extends StatelessWidget {
  final ForumAttachment attachment;
  final bool viewerIsAuthor;
  final String authorName;
  final VoidCallback? onRemove;

  const ForumAttachmentCard({
    super.key,
    required this.attachment,
    required this.viewerIsAuthor,
    required this.authorName,
    this.onRemove,
  });

  void _open(BuildContext context) {
    if (viewerIsAuthor) {
      switch (attachment.kind) {
        case ForumAttachmentKind.ride:
          context.push('/ride/summary/${attachment.refId}');
        case ForumAttachmentKind.maintenance:
          final bike = attachment.bikeId;
          context.push(bike == null
              ? '/home/maintenance'
              : '/home/maintenance?bikeId=${Uri.encodeComponent(bike)}');
      }
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.surface,
        title: Text(attachment.title, style: TextStyle(color: ctx.palette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(attachment.subtitle, style: TextStyle(color: ctx.palette.textSecondary)),
            const SizedBox(height: 12),
            Text(
              ctx.l10n.attachmentSharedFrom(authorName),
              style: TextStyle(fontSize: 12, color: ctx.palette.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRide = attachment.kind == ForumAttachmentKind.ride;
    final accent = isRide ? context.palette.primary : context.palette.success;
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        onTap: onRemove == null ? () => _open(context) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.shape.radiusMd),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(isRide ? Icons.route : Icons.build_outlined, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRide
                          ? context.l10n.forumAttachmentRide
                          : context.l10n.forumAttachmentMaintenance,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: accent,
                      ),
                    ),
                    Text(
                      attachment.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    if (attachment.subtitle.isNotEmpty)
                      Text(
                        attachment.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: context.l10n.forumRemoveAttachment,
                  onPressed: onRemove,
                  icon: Icon(Icons.close, size: 18, color: context.palette.textTertiary),
                )
              else
                Icon(Icons.chevron_right, color: context.palette.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
