import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/sensor_constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/speed_alert_provider.dart';

/// Settings → Ride tracking: the overspeed alert threshold slider.
class SettingsOverspeedLimitTile extends ConsumerWidget {
  const SettingsOverspeedLimitTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final limit = ref.watch(overspeedLimitProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: context.palette.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.overspeedSettingTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.overspeedSettingSubtitle,
                      style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '${limit.round()} km/h',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: context.palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.palette.primary,
              inactiveTrackColor:
                  context.palette.primary.withValues(alpha: 0.2),
              thumbColor: context.palette.primary,
            ),
            child: Slider(
              value: limit,
              min: SensorConstants.minOverspeedKmh,
              max: SensorConstants.maxOverspeedKmh,
              divisions: 16,
              label: '${limit.round()} km/h',
              onChanged: (val) {
                ref.read(overspeedLimitProvider.notifier).setLimit(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
