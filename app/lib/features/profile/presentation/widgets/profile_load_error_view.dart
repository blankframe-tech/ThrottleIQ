import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Why another rider's profile failed to load.
enum ProfileLoadFailure { private, offline, other }

/// Maps a profile-stream error to what the rider should be told.
///
/// The profile screen used to say "This profile is private" for every
/// error, so a rider on a dead connection was told a public profile was
/// private. Only `permission-denied` (the rules refusing the read) means
/// private; network-shaped failures are "offline" and worth a retry.
ProfileLoadFailure classifyProfileError(Object error) {
  if (error is TimeoutException) return ProfileLoadFailure.offline;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => ProfileLoadFailure.private,
      'unavailable' || 'deadline-exceeded' => ProfileLoadFailure.offline,
      _ => ProfileLoadFailure.other,
    };
  }
  return ProfileLoadFailure.other;
}

/// Error body for the profile screen: private (no retry, retrying won't
/// change the rules), offline or generic failure (both with Retry).
class ProfileLoadErrorView extends StatelessWidget {
  final ProfileLoadFailure failure;
  final VoidCallback onRetry;

  const ProfileLoadErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (failure) {
      ProfileLoadFailure.private => (Icons.lock_outline, 'This profile is private'),
      ProfileLoadFailure.offline => (Icons.wifi_off, "You're offline"),
      ProfileLoadFailure.other => (Icons.error_outline, "Couldn't load profile"),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            if (failure != ProfileLoadFailure.private) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
