import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../maintenance/domain/calculators/maintenance_forecast.dart';
import '../../../maintenance/domain/entities/maintenance_entity.dart';
import '../service_type_l10n.dart';

/// A multi-gauge health card displaying wear and remaining life percentages for
/// 4 key motorcycle consumables: Engine Oil, Drive Chain, Brake Pads, and Tires.
class ConsumablesHealthCard extends StatelessWidget {
  final List<CheckForecast> forecasts;
  final void Function(ServiceType type)? onSelectConsumable;

  const ConsumablesHealthCard({
    super.key,
    required this.forecasts,
    this.onSelectConsumable,
  });

  static const List<ServiceType> trackedTypes = [
    ServiceType.oilChange,
    ServiceType.chain,
    ServiceType.frontDiscPads,
    ServiceType.tire,
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MACHINE VITALS',
                style: AppTypography.cockpitLabel(
                  context,
                  color: context.palette.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'WEAR MONITOR',
                style: AppTypography.cockpitLabel(
                  context,
                  color: context.palette.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final type in trackedTypes)
                _ConsumableGauge(
                  type: type,
                  forecast: _findForecast(type),
                  onTap: onSelectConsumable != null
                      ? () => onSelectConsumable!(type)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  CheckForecast? _findForecast(ServiceType type) {
    for (final f in forecasts) {
      if (f.serviceType == type) return f;
    }
    return null;
  }
}

class _ConsumableGauge extends StatelessWidget {
  final ServiceType type;
  final CheckForecast? forecast;
  final VoidCallback? onTap;

  const _ConsumableGauge({
    required this.type,
    required this.forecast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (lifeFraction, isOverdue, labelText) = _computeHealth();

    final Color ringColor;
    if (isOverdue) {
      ringColor = context.palette.danger;
    } else if (lifeFraction < 0.25) {
      ringColor = context.palette.warning;
    } else {
      ringColor = context.palette.primary;
    }

    final pctText = isOverdue
        ? 'DUE'
        : forecast == null
            ? '—'
            : '${(lifeFraction * 100).round()}%';

    final shortName = switch (type) {
      ServiceType.oilChange => 'OIL',
      ServiceType.chain => 'CHAIN',
      ServiceType.frontDiscPads => 'BRAKES',
      ServiceType.tire => 'TIRES',
      _ => type.localizedLabel(context.l10n).toUpperCase(),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: isOverdue ? 1.0 : lifeFraction,
                    strokeWidth: 4.5,
                    backgroundColor: context.palette.border.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(type),
                        size: 16,
                        color: isOverdue ? ringColor : context.palette.textSecondary,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        pctText,
                        style: display(context, 10,
                            weight: FontWeight.w700, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              shortName,
              style: AppTypography.cockpitLabel(
                context,
                color: context.palette.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              labelText,
              style: TextStyle(
                fontSize: 9,
                color: isOverdue ? ringColor : context.palette.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  (double life, bool overdue, String label) _computeHealth() {
    if (forecast == null) return (1.0, false, 'No data');

    final f = forecast!;
    final isOverdue = f.status == ReminderStatus.overdue;

    // Remaining distance or days
    if (f.kmLeft != null) {
      final km = f.kmLeft!;
      final interval = f.kmLimit > 0 ? f.kmLimit : 3000.0;
      final fraction = (km / interval).clamp(0.0, 1.0);
      final label = isOverdue
          ? '${km.abs().round()} km past'
          : '${km.round()} km left';
      return (fraction, isOverdue, label);
    }

    if (f.daysLeft != null) {
      final days = f.daysLeft!;
      final interval = (f.daysLimit != null && f.daysLimit! > 0)
          ? f.daysLimit!.toDouble()
          : 180.0;
      final fraction = (days / interval).clamp(0.0, 1.0);
      final label = isOverdue ? '${days.abs()}d past' : '${days}d left';
      return (fraction, isOverdue, label);
    }

    return (1.0, false, 'OK');
  }

  IconData _iconFor(ServiceType t) => switch (t) {
        ServiceType.oilChange => Icons.opacity,
        ServiceType.chain => Icons.link,
        ServiceType.frontDiscPads => Icons.disc_full,
        ServiceType.tire => Icons.album,
        _ => Icons.build,
      };
}
