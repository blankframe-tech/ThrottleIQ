import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';

/// Customer-facing stand-in for a raw exception in a `.when(error: ...)`
/// branch — maps [error] through [mapFirestoreError] rather than
/// interpolating it straight into a `Text` widget, and gives the rider an
/// obvious next step (retry) instead of a dead end.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

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
          ],
        ),
      ),
    );
  }
}
