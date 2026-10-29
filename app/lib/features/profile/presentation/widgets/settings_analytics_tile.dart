import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/analytics/analytics_service.dart';

/// Settings → Privacy & Safety: the opt-out for anonymous usage statistics
/// (issues §83.27). Applies immediately and persists.
class SettingsAnalyticsTile extends StatefulWidget {
  const SettingsAnalyticsTile({super.key});

  @override
  State<SettingsAnalyticsTile> createState() => _SettingsAnalyticsTileState();
}

class _SettingsAnalyticsTileState extends State<SettingsAnalyticsTile> {
  bool _enabled = AnalyticsService.instance.enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_outlined,
              color: context.palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.shareUsageStats,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(context.l10n.shareUsageStatsDesc,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              AnalyticsService.instance.setEnabled(v);
            },
          ),
        ],
      ),
    );
  }
}
