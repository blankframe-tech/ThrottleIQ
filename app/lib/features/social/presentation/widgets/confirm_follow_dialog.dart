import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';

/// "Follow <name>?" before a follow link or scanned QR code follows anyone
/// (FollowLinkController.followUid's `confirm`). True only on the Follow tap.
Future<bool> confirmFollowFromLink(BuildContext context, String name) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.followLinkConfirmTitle(name)),
      content: Text(dialogContext.l10n.followLinkConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.cancelAction),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.follow),
        ),
      ],
    ),
  );
  return agreed == true;
}
