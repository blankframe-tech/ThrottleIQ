import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/follow_providers.dart';

/// Where a [FollowButton] sits, which decides its shape.
enum FollowButtonVariant {
  /// Small outlined button at the end of a rider row (search, Following,
  /// All People).
  tile,

  /// Full-width compact outlined button on a "Suggested for you" card.
  card,

  /// Filled, full-width button on a rider's profile.
  prominent,
}

/// Follow / unfollow toggle for [targetUid] (issues §90.A9).
///
/// Every follow button used to fire the write unawaited and send the follow
/// notification regardless of whether the follow landed, with nothing to
/// stop a double tap. This awaits the write through [FollowController]
/// (which notifies only after it lands), disables itself while the write is
/// in flight, and shows the error if it's rejected. State comes from
/// [isFollowingProvider], which derives from the one live follow-set
/// listener, so it flips the moment the local cache does.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.targetUid,
    this.variant = FollowButtonVariant.tile,
  });

  final String targetUid;
  final FollowButtonVariant variant;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  Future<void> _toggle(bool isFollowing) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(followControllerProvider).setFollowing(
            widget.targetUid,
            follow: !isFollowing,
            fallbackName: context.l10n.aRider,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(mapFirestoreError(e, context.l10n))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    if (myUid == null || myUid == widget.targetUid) {
      return const SizedBox.shrink();
    }
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUid));

    return isFollowingAsync.when(
      loading: () => switch (widget.variant) {
        FollowButtonVariant.tile => const SizedBox(width: 80),
        FollowButtonVariant.card => const SizedBox(height: 28),
        FollowButtonVariant.prominent => const SizedBox(height: 40),
      },
      error: (_, __) => const SizedBox.shrink(),
      data: (isFollowing) {
        final label =
            isFollowing ? context.l10n.following : context.l10n.follow;
        final onPressed = _busy ? null : () => _toggle(isFollowing);
        final child = _busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.palette.primary),
              )
            : Text(label,
                style: widget.variant == FollowButtonVariant.card
                    ? const TextStyle(fontSize: 12)
                    : null);

        return switch (widget.variant) {
          FollowButtonVariant.tile => OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: child,
            ),
          FollowButtonVariant.card => OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 28),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: child,
            ),
          FollowButtonVariant.prominent => ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? context.palette.surfaceVariant
                    : context.palette.primary,
                foregroundColor:
                    isFollowing ? context.palette.textPrimary : Colors.white,
              ),
              child: child,
            ),
        };
      },
    );
  }
}
