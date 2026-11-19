import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import 'edit_maintenance_check_sheet.dart';
import 'forecast_text.dart';
import 'maintenance_check_row.dart' show canOrderPartsProvider;
import 'maintenance_format.dart';
import 'order_part_sheet.dart';
import 'quick_service_sheet.dart';

/// Deep Part Detail Sheet: Slides up when tapping any maintenance row.
/// Displays component wear countdown, visual progress, OEM vs custom interval source,
/// adaptive wear factors breakdown (Dhaka road dust, aggressive throttle, short trips),
/// and immediate action buttons (Quick Log, Calibrate Interval, Order Part).
class CheckDetailsSheet extends ConsumerWidget {
  final BikeEntity bike;
  final CheckForecast forecast;
  final bool imperial;

  const CheckDetailsSheet({
    super.key,
    required this.bike,
    required this.forecast,
    required this.imperial,
  });

  static Future<void> show(
    BuildContext context, {
    required BikeEntity bike,
    required CheckForecast forecast,
    required bool imperial,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckDetailsSheet(
        bike: bike,
        forecast: forecast,
        imperial: imperial,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final shape = context.shape;
    final l10n = context.l10n;
    final f = forecast;

    final configs =
        ref.watch(maintenanceConfigProvider(bike.id)).valueOrNull ?? const [];
    final config = configs.where((c) => c.key == f.key).firstOrNull;
    final profile = ref.watch(maintenanceProfileProvider(bike.id)).valueOrNull;

    final color = statusColor(context, f.status);
    final canOrder =
        ref.watch(canOrderPartsProvider) && isOrderable(f.serviceType);

    final statusText = switch (f.status) {
      ReminderStatus.overdue => l10n.statusOverdue.toUpperCase(),
      ReminderStatus.dueSoon => l10n.dueSoon.toUpperCase(),
      ReminderStatus.ok => l10n.statusOk.toUpperCase(),
      ReminderStatus.unknown => l10n.statusUnknown.toUpperCase(),
    };

    final title = forecastLabel(f, l10n);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: palette.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(shape.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header: Component name, status pill, icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(
                    iconForServiceType(f.serviceType),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: AppTypography.display(context, 16,
                            weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deep wear inspection, interval source & adaptive factors',
                        style: TextStyle(
                            fontSize: 11.5, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      Icon(Icons.close, color: palette.textTertiary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Wear Countdown & Visual Progress Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(shape.radiusMd),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          rowRemainingText(f, l10n, imperial).toUpperCase(),
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (f.dueDate != null &&
                          f.status != ReminderStatus.overdue)
                        Text(
                          'DUE ~ ${shortDate(context, f.dueDate!)}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.textSecondary,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(shape.radiusSm),
                            border:
                                Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Visual Wear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: f.status == ReminderStatus.unknown
                            ? 0.0
                            : f.progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (config != null && config.intervalKm > 0)
                        'Interval: Every ${distLabelLong(config.intervalKm, imperial)}'
                      else if (f.kmLimit > 0)
                        'Interval: Every ${distLabelLong(f.kmLimit, imperial)}',
                      if (config?.intervalDays != null)
                        'or ${config!.intervalDays} days',
                      '· Source: ${config?.source == IntervalSource.user ? "User Custom Calibration" : "OEM Schedule (${profile?.template.name ?? bike.displayName})"}',
                    ].join(' '),
                    style:
                        TextStyle(fontSize: 11.5, color: palette.textSecondary),
                  ),
                  if (f.lastServiceDate != null || f.lastServiceKm != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last serviced: ${[
                        if (f.lastServiceDate != null)
                          shortDate(context, f.lastServiceDate!),
                        if (f.lastServiceKm != null)
                          distLabelLong(f.lastServiceKm!, imperial),
                      ].join(' · ')}',
                      style:
                          TextStyle(fontSize: 11, color: palette.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (f.isAdapted && f.reasons.isNotEmpty) ...[
              // Adaptive Wear Multipliers Breakdown (Engine Insights)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(shape.radiusMd),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADAPTIVE WEAR MULTIPLIERS (THROTTLEIQ ENGINE)',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...[
                      for (final r in f.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                  style: TextStyle(
                                      color: palette.attention,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  adaptReasonLabel(r, l10n),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: palette.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Actions: [⚡ Log This Service Now], [⚙️ Calibrate Interval], [🛒 Order Part]
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bolt, size: 18),
                      label: Text(
                        '⚡ LOG THIS SERVICE',
                        style: AppTypography.display(
                          context,
                          12,
                          color: Colors.black,
                          weight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(shape.radiusMd),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        QuickServiceSheet.show(
                          context,
                          bike: bike,
                          initialForecast: f,
                          initialTitle: title,
                          initialServiceType: f.serviceType,
                        );
                      },
                    ),
                  ),
                ),
                if (config != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text(
                          'CALIBRATE',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(shape.radiusMd),
                          ),
                        ),
                        onPressed: () {
                          // The sheet's own context dies with the pop.
                          final host = Navigator.of(context).context;
                          Navigator.of(context).pop();
                          EditMaintenanceCheckSheet.show(host, config: config);
                        },
                      ),
                    ),
                  ),
                ],
                if (canOrder) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(shape.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () {
                        final host = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        OrderPartSheet.show(host, f.serviceType);
                      },
                      child: const Text('🛒'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
