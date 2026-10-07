import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../maintenance_l10n.dart';
import 'forecast_text.dart';

/// The next [horizonDays] on one line, each due item on its projected date
/// and overdue ones pinned left of "today". Replaces the old overdue / due /
/// OK count card: counts say how much is wrong, a timeline says what to do
/// when.
class ForecastStrip extends StatelessWidget {
  final String bikeId;
  final List<CheckForecast> forecasts;
  static const horizonDays = 60;
  static const _maxItems = 6;

  const ForecastStrip({super.key, required this.bikeId, required this.forecasts});

  /// The items the strip shows: datable, not low-stakes, within the horizon.
  static List<CheckForecast> visible(List<CheckForecast> all, DateTime now) {
    return all
        .where((f) =>
            !f.serviceType.isLowStakes &&
            f.status != ReminderStatus.unknown &&
            (f.status == ReminderStatus.overdue ||
                (f.daysUntilDue(now) != null &&
                    f.daysUntilDue(now)! <= horizonDays)))
        .take(_maxItems)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = visible(forecasts, now);
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialLabel(l10n.comingUpNextDays(horizonDays)),
        const SizedBox(height: 8),
        SizedBox(
          height: 86,
          child: LayoutBuilder(builder: (context, c) {
            const inset = 28.0;
            final width = c.maxWidth - inset * 2;
            double xFor(CheckForecast f) {
              if (f.status == ReminderStatus.overdue) return inset - 14;
              final d = (f.daysUntilDue(now) ?? 0).clamp(0, horizonDays);
              return inset + width * d / horizonDays;
            }

            final children = <Widget>[
              Positioned(
                left: inset,
                right: inset,
                top: 36,
                child: Container(height: 1.5, color: context.palette.border),
              ),
              Positioned(
                left: inset - 0.75,
                top: 22,
                child: Container(
                    width: 1.5, height: 30, color: context.palette.danger),
              ),
              Positioned(
                left: 0,
                width: inset * 2,
                top: 70,
                child: Text(l10n.today,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.palette.danger)),
              ),
            ];
            for (var i = 0; i < items.length; i++) {
              final f = items[i];
              final x = xFor(f);
              final above = i.isEven;
              final color = statusColor(context, f.status);
              children.add(Positioned(
                left: math.max(0.0, x - 40),
                width: 80,
                top: above ? 0 : 44,
                child: GestureDetector(
                  onTap: () => context.push(
                      '/home/maintenance/check?bikeId=$bikeId&key=${Uri.encodeComponent(f.key)}'),
                  child: Text(
                    forecastLabel(f, l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5, color: context.palette.textSecondary),
                  ),
                ),
              ));
              children.add(Positioned(
                left: x - 7,
                top: 30,
                child: GestureDetector(
                  onTap: () => context.push(
                      '/home/maintenance/check?bikeId=$bikeId&key=${Uri.encodeComponent(f.key)}'),
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: f.status == ReminderStatus.ok
                            ? context.palette.textTertiary
                            : color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ));
            }
            return Stack(clipBehavior: Clip.none, children: children);
          }),
        ),
      ],
    );
  }
}
