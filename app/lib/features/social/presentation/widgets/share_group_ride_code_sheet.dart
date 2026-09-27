import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Modal sheet showing a group ride's join code back to a rider who already
/// has it — the missing "share" half of the code door in
/// `group_ride_join_code.dart`. The code has existed on every ride since
/// creation, but nothing ever displayed it: this is that screen, reached from
/// [GroupRideMapScreen]'s AppBar while the ride is active.
class ShareGroupRideCodeSheet extends StatelessWidget {
  final String code;
  final String rideName;

  const ShareGroupRideCodeSheet({
    super.key,
    required this.code,
    required this.rideName,
  });

  static Future<void> show(
    BuildContext context, {
    required String code,
    required String rideName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.background,
      builder: (_) => ShareGroupRideCodeSheet(code: code, rideName: rideName),
    );
  }

  void _copy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareRideCodeCopied)));
  }

  void _share(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Share.share(l10n.shareRideCodeMessage(rideName, code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            l10n.shareRideCodeTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.shareRideCodeSubtitle,
            style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(context.shape.radiusMd),
              border: Border.all(color: context.palette.border),
            ),
            alignment: Alignment.center,
            child: Text(
              code,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(l10n.shareRideCodeCopyAction, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(l10n.shareRideCodeShareAction, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
