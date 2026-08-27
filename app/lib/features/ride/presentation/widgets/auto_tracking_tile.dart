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

/// "Only watch during these hours" control, shown directly under
/// [AutoTrackingTile] and only while auto-tracking is actually on — picking
/// a window for a feature that's off has nothing to attach to yet.
///
/// Not localized (unlike the tile above it): this Settings screen is
/// otherwise the one fully-localized screen in the app, but adding a new
/// feature's copy to both `app_en.arb` and `app_bn.arb` — with a real,
/// reviewed Bangla translation rather than a placeholder — is out of scope
/// for this change. Tracked as a gap, not silently skipped.
class AutoTrackingScheduleTile extends ConsumerWidget {
  const AutoTrackingScheduleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingOn =
        ref.watch(autoTrackingEnabledProvider).valueOrNull ?? false;
    if (!trackingOn) return const SizedBox.shrink();

    final schedule = ref.watch(autoTrackingScheduleProvider).valueOrNull;
    if (schedule == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: schedule.enabled,
            onChanged: (value) =>
                ref.read(autoTrackingScheduleProvider.notifier).setEnabled(value),
            title: const Text('Active hours',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(schedule.enabled
                ? 'Only watching for rides between '
                    '${_formatMinutes(schedule.startMinutes)} and '
                    '${_formatMinutes(schedule.endMinutes)}.'
                : 'Watching for rides all day.'),
            secondary: Icon(Icons.schedule, color: AppColors.primary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          if (schedule.enabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'From',
                      minutes: schedule.startMinutes,
                      onPicked: (picked) => _updateWindow(
                          context, ref, start: picked, end: schedule.endMinutes),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Until',
                      minutes: schedule.endMinutes,
                      onPicked: (picked) => _updateWindow(
                          context, ref,
                          start: schedule.startMinutes, end: picked),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateWindow(
    BuildContext context,
    WidgetRef ref, {
    required int start,
    required int end,
  }) async {
    if (start >= end) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('The start time must be before the end time.'),
      ));
      return;
    }
    await ref.read(autoTrackingScheduleProvider.notifier).setWindow(start, end);
  }

  static String _formatMinutes(int minutes) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onPicked;
  const _TimeField(
      {required this.label, required this.minutes, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (picked != null) onPicked(picked.hour * 60 + picked.minute);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          Text(AutoTrackingScheduleTile._formatMinutes(minutes)),
        ],
      ),
    );
  }
}
