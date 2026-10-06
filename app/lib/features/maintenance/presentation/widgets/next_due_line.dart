import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import 'forecast_text.dart';

/// One line naming a bike's next maintenance item — on the garage card and
/// bike detail, so a rider with several bikes sees each one's next job
/// without switching bikes on the Maintenance page.
class NextDueLine extends ConsumerWidget {
  final String bikeId;
  final double fontSize;
  const NextDueLine({super.key, required this.bikeId, this.fontSize = 12});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final f = ref.watch(maintenanceUpNextProvider(bikeId));
    if (f == null) {
      return Text(l10n.usingDefaultServiceIntervals,
          style: TextStyle(fontSize: fontSize, color: context.palette.textTertiary));
    }
    final imperial = ref.watch(maintenanceImperialProvider);
    final when = dueWhenText(f, l10n, DateTime.now());
    final color = f.status == ReminderStatus.ok
        ? context.palette.textSecondary
        : statusColor(context, f.status);
    return Text(
      l10n.nextDueLine(
        forecastLabel(f, l10n),
        when.isNotEmpty && f.status != ReminderStatus.overdue
            ? when
            : rowRemainingText(f, l10n, imperial),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: fontSize,
          fontWeight: f.needsAttention ? FontWeight.w600 : FontWeight.normal,
          color: color),
    );
  }
}
