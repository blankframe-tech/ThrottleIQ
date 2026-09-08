import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import 'bug_report_sheet.dart';

/// Customer-facing stand-in for a raw exception in a `.when(error: ...)`
/// branch — maps [error] through [mapFirestoreError] rather than
/// interpolating it straight into a `Text` widget, and gives the rider an
/// obvious next step (retry) instead of a dead end.
///
/// Set [showBugReport] to `true` on screens where a persistent error warrants
/// a bug report button — e.g. the chat screens — so the rider can send
/// diagnostic info without digging into Settings.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  /// When true, shows a "Report a Problem" link below the retry button.
  final bool showBugReport;

  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.showBugReport = false,
  });

  @override
  Widget build(BuildContext context) {
    final message = mapFirestoreError(error);
    final offline = message.startsWith("You're offline");

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
            if (showBugReport) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => BugReportSheet.show(context),
                icon: const Icon(Icons.bug_report_outlined, size: 16),
                label: const Text('Report a Problem'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
