import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auto_tracking_provider.dart';

/// Settings control for automatic ride detection.
///
/// The battery figure in the subtitle is deliberate and specific. Riders are a
/// technical, sceptical audience and "uses some battery" reads as evasion;
/// naming the number is what makes the ask credible. It is also honest — the
/// idle cost really is a few percent a day, because detection runs on platform
/// activity recognition and never polls GPS. See docs/AUTO_TRACKING_PLAN.md.
class AutoTrackingTile extends ConsumerWidget {
  const AutoTrackingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(autoTrackingEnabledProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: enabled.valueOrNull ?? false,
        onChanged: enabled.isLoading
            ? null
            : (value) => _toggle(context, ref, value),
        title: Text(
          l10n.autoTrackingTileTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(l10n.autoTrackingTileSubtitle),
        secondary: Icon(Icons.motorcycle, color: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final notifier = ref.read(autoTrackingEnabledProvider.notifier);

    if (!value) {
      await notifier.disable();
      return;
    }

    final failure = await notifier.enable();
    if (failure == null || !context.mounted) return;

    // Enabling can fail for reasons the rider can act on (services off,
    // permission refused), so the failure is surfaced rather than the switch
    // silently springing back with no explanation.
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_message(l10n, failure)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _message(AppLocalizations l10n, AutoTrackingEnableFailure failure) {
    switch (failure) {
      case AutoTrackingEnableFailure.locationServicesOff:
        return l10n.autoTrackingLocationServicesOffMessage;
      case AutoTrackingEnableFailure.permissionDenied:
        return l10n.autoTrackingPermissionDeniedMessage;
      case AutoTrackingEnableFailure.alwaysPermissionRequired:
        return l10n.autoTrackingAlwaysPermissionRequiredMessage;
      case AutoTrackingEnableFailure.startFailed:
        return l10n.autoTrackingStartFailedMessage;
    }
  }
}
