import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_registry.dart';
import 'analytics_chart_view.dart';

/// One compact chart on the Rides tab's analytics list: title, a small
/// chart and a one-line insight. Tapping opens the detail view.
class AnalyticsChartCard extends StatelessWidget {
  final AnalyticsChart chart;
  final List<AnalyticsPoint> points;
  final String? insight;
  final VoidCallback onTap;
  final String Function(String bikeId) bikeName;

  const AnalyticsChartCard({
    super.key,
    required this.chart,
    required this.points,
    required this.onTap,
    required this.bikeName,
    this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final spec = chartPresentationOf(chart);
    final title = spec.title(context.l10n);
    return Semantics(
      button: true,
      label: title,
      child: EditorialCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(spec.icon, size: 15, color: spec.colorOf(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: context.palette.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnalyticsChartView(
              chart: chart,
              points: points,
              bikeName: bikeName,
            ),
            if (insight != null) ...[
              const SizedBox(height: 6),
              Text(
                insight!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
