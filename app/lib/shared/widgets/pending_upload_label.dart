import 'package:flutter/material.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/theme/app_theme_context.dart';

/// Muted "Waiting to upload" tag on a ride comment, forum post or reply the
/// rider wrote that Firestore still has queued on this phone (offline, or the
/// daily quota is spent), so nobody else can see it yet (issue #158).
class PendingUploadLabel extends StatelessWidget {
  const PendingUploadLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.textTertiary; // AA on every surface
    final label = context.l10n.waitingToUpload;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}
