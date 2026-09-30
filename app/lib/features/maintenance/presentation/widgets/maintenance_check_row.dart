import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'edit_maintenance_check_sheet.dart';
import 'maintenance_format.dart';

/// One tracked check: status, wear progress, and per-item Edit / Log.
class MaintenanceCheckRow extends ConsumerWidget {
  final MaintenanceReminder reminder;
  final bool imperial;
  final String bikeId;

  const MaintenanceCheckRow({
    super.key,
    required this.reminder,
    required this.imperial,
    required this.bikeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, barColor, label) = switch (reminder.status) {
      ReminderStatus.overdue => (PillTone.overdue, context.palette.danger, context.l10n.statusOverdue),
      ReminderStatus.dueSoon => (PillTone.dueSoon, context.palette.attention, context.l10n.dueSoon),
      ReminderStatus.ok => (PillTone.ok, context.palette.success, context.l10n.statusOk),
    };
    final isOverdue = reminder.status == ReminderStatus.overdue;
    final progress = reminder.kmLimit > 0
        ? (reminder.kmSinceService / reminder.kmLimit).clamp(0.0, 1.0)
        : 0.0;
    final kmLeft = reminder.kmLimit - reminder.kmSinceService;
    final rightText = kmLeft >= 0
        ? '${distLabel(kmLeft, imperial)} left'
        : '${distLabel(-kmLeft, imperial)} over';

    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      borderColor: isOverdue ? context.palette.danger : context.palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconForServiceType(reminder.serviceType),
                size: 18,
                color: barColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reminder.serviceType.localizedLabel(context.l10n),
                    style: display(context, 15, letterSpacing: 0)),
              ),
              EditorialPill(label, tone: tone, filled: isOverdue),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.intervalEvery(distLabel(reminder.kmLimit, imperial)),
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
              Text(rightText,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: isOverdue ? FontWeight.w700 : FontWeight.normal,
                      color: isOverdue ? context.palette.danger : context.palette.textSecondary)),
            ],
          ),
          if (reminder.notes != null && reminder.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.palette.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(context.shape.radiusSm),
                border:
                    Border.all(color: context.palette.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notes, size: 12, color: context.palette.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      reminder.notes!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          EditorialProgress(progress, color: barColor, height: 5),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reminder.lastServiceDate != null
                    ? context.l10n.lastDone(formatServiceDate(reminder.lastServiceDate!))
                    : context.l10n.noPreviousServiceRecorded,
                style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      final configs = ref
                              .read(maintenanceConfigProvider(bikeId))
                              .valueOrNull ??
                          [];
                      final currentConfig = configs.firstWhere(
                        (c) => c.serviceType == reminder.serviceType,
                        orElse: () => MaintenanceConfigEntity(
                          bikeId: bikeId,
                          serviceType: reminder.serviceType,
                          intervalKm: reminder.kmLimit,
                          isEnabled: true,
                          notes: reminder.notes,
                        ),
                      );
                      EditMaintenanceCheckSheet.show(context,
                          config: currentConfig);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(context.shape.radiusSm),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 12, color: context.palette.textSecondary),
                          const SizedBox(width: 2),
                          Text(context.l10n.edit,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => context.go(
                        '/home/maintenance/add?bikeId=$bikeId&serviceType=${reminder.serviceType.name}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(context.shape.radiusSm),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 12, color: context.palette.primary),
                          const SizedBox(width: 2),
                          Text(context.l10n.log,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// All / Needs attention / OK filter pill above the checks list.
class MaintenanceFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final PillTone? tone;
  final VoidCallback onTap;

  const MaintenanceFilterChip({
    super.key,
    required this.label,
    required this.active,
    this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = active
        ? (tone == PillTone.overdue
            ? context.palette.danger.withValues(alpha: 0.2)
            : (tone == PillTone.ok
                ? context.palette.success.withValues(alpha: 0.2)
                : context.palette.ink))
        : Colors.transparent;

    final textColor = active
        ? (tone == PillTone.overdue
            ? context.palette.danger
            : (tone == PillTone.ok
                ? context.palette.success
                : context.palette.onInk))
        : context.palette.textTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
          border: Border.all(
            color: active ? Colors.transparent : context.palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

