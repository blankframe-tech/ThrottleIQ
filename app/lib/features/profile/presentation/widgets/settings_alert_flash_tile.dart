import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../providers/speed_alert_provider.dart';

/// Settings → Ride tracking: turns the cockpit's alert flash on or off.
class SettingsAlertFlashTile extends ConsumerWidget {
  const SettingsAlertFlashTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flash_on_outlined,
              color: context.palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.alertFlashSettingTitle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(context.l10n.alertFlashSettingSubtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: ref.watch(alertFlashProvider),
            onChanged: ref.read(alertFlashProvider.notifier).setEnabled,
          ),
        ],
      ),
    );
  }
}
