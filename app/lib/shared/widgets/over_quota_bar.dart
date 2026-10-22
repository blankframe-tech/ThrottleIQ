import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/firestore_quota.dart';
import '../../core/i18n/l10n_context.dart';
import '../../core/theme/app_theme_context.dart';

/// Pinned above the bottom nav on every shell screen while Firestore is over
/// its daily quota (§104). It tells the rider why feeds look stale and that
/// what they saved is safe on the phone and will sync by itself.
class OverQuotaBar extends ConsumerWidget {
  const OverQuotaBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firestorePausedProvider)) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border(
            top: BorderSide(color: context.palette.border, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 20, color: context.palette.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.overQuotaBar,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
