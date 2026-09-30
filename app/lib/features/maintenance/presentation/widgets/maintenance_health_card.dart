import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';

/// Overdue / due-soon / good summary with a distribution bar.
class MaintenanceHealthCard extends StatelessWidget {
  final int overdue;
  final int dueSoon;
  final int ok;

  const MaintenanceHealthCard({
    super.key,
    required this.overdue,
    required this.dueSoon,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final total = overdue + dueSoon + ok;
    if (total == 0) return const SizedBox.shrink();

    final Color statusColor;
    final String statusTitle;
    final String statusSubtitle;
    final IconData statusIcon;

    if (overdue > 0) {
      statusColor = context.palette.danger;
      statusTitle =
          '$overdue ${overdue == 1 ? 'Service Overdue' : 'Services Overdue'}';
      statusSubtitle = context.l10n.immediateMaintenanceAttentionRecommended;
      statusIcon = Icons.warning_amber_rounded;
    } else if (dueSoon > 0) {
      statusColor = context.palette.attention;
      statusTitle =
          '$dueSoon ${dueSoon == 1 ? 'Service Due Soon' : 'Services Due Soon'}';
      statusSubtitle = context.l10n.upcomingScheduledMaintenance;
      statusIcon = Icons.schedule;
    } else {
      statusColor = context.palette.success;
      statusTitle = context.l10n.allSystemsNominal;
      statusSubtitle = context.l10n.allTrackedComponentsGood(total);
      statusIcon = Icons.verified_outlined;
    }

    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      borderColor: statusColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusTitle,
                        style: display(context, 15, letterSpacing: 0)),
                    const SizedBox(height: 2),
                    Text(statusSubtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: context.palette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                if (overdue > 0)
                  Expanded(
                    flex: overdue,
                    child: Container(height: 6, color: context.palette.danger),
                  ),
                if (dueSoon > 0)
                  Expanded(
                    flex: dueSoon,
                    child:
                        Container(height: 6, color: context.palette.attention),
                  ),
                if (ok > 0)
                  Expanded(
                    flex: ok,
                    child: Container(height: 6, color: context.palette.success),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricPill('Overdue', overdue, context.palette.danger),
              _MetricPill(context.l10n.dueSoonTitle, dueSoon,
                  context.palette.attention),
              _MetricPill('Good', ok, context.palette.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MetricPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: count > 0
                ? context.palette.textSecondary
                : context.palette.textTertiary,
          ),
        ),
      ],
    );
  }
}
