import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import 'edit_maintenance_check_sheet.dart' show iconForServiceType;
import '../../../../core/i18n/l10n_context.dart';
import '../service_type_l10n.dart';

/// Bottom sheet for the "master service log" reset: lets the rider tick
/// which tracked checks were just serviced (all or a subset) and logs each
/// as done "now" at the bike's current odometer, resetting its interval
/// countdown while keeping prior history intact.
class ResetMaintenanceLogSheet extends ConsumerStatefulWidget {
  final BikeEntity bike;

  const ResetMaintenanceLogSheet({super.key, required this.bike});

  static Future<void> show(BuildContext context, BikeEntity bike) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResetMaintenanceLogSheet(bike: bike),
    );
  }

  @override
  ConsumerState<ResetMaintenanceLogSheet> createState() =>
      _ResetMaintenanceLogSheetState();
}

class _ResetMaintenanceLogSheetState
    extends ConsumerState<ResetMaintenanceLogSheet> {
  final Set<ServiceType> _selected = {};
  bool _resetting = false;

  void _toggle(ServiceType type) {
    setState(() {
      if (_selected.contains(type)) {
        _selected.remove(type);
      } else {
        _selected.add(type);
      }
    });
  }

  Future<void> _confirmReset(List<MaintenanceReminder> reminders) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.resetSelectedItems),
        content: Text(
          _selected.length == 1
              ? ctx.l10n.thisLogsAsServiced(_selected.first.label)
              : ctx.l10n.thisLogsItemsAs(_selected.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);

    final bikes = ref.read(garageProvider).valueOrNull ?? [];
    final currentBike =
        bikes.where((b) => b.id == widget.bike.id).firstOrNull ?? widget.bike;
    final count = _selected.length;

    await ref.read(maintenanceProvider(widget.bike.id).notifier).resetItems(
          _selected.toList(),
          odometerKm: currentBike.currentOdometerKm,
        );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.palette.surfaceVariant,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: context.palette.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 1
                    ? context.l10n.n1ItemResetServiced
                    : context.l10n.itemsResetServicedToday(count),
                style: TextStyle(color: context.palette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(maintenanceRemindersProvider(widget.bike.id));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMd,
        16,
        AppDimensions.paddingMd,
        16 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restart_alt, color: context.palette.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.resetServiceLogTitle, style: display(context, 18)),
                    Text(
                      context.l10n.tickWhatJustServiced(widget.bike.displayName),
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.selectedItemsLoggedAs,
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (reminders.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  context.l10n.noTrackedChecksYet,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _selected.addAll(reminders.map((r) => r.serviceType))),
                  child: Text(context.l10n.selectAll, style: const TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
                  child: Text(context.l10n.clear,
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                ),
                const Spacer(),
                Text(context.l10n.selectedOfTotal(_selected.length, reminders.length),
                    style: TextStyle(fontSize: 11, color: context.palette.textTertiary)),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final reminder in reminders) ...[
                      _ResetItemTile(
                        reminder: reminder,
                        selected: _selected.contains(reminder.serviceType),
                        onTap: () => _toggle(reminder.serviceType),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty || _resetting
                    ? null
                    : () => _confirmReset(reminders),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _resetting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _selected.isEmpty
                            ? context.l10n.selectItemsReset
                            : context.l10n.resetItemsButton(_selected.length),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResetItemTile extends StatelessWidget {
  final MaintenanceReminder reminder;
  final bool selected;
  final VoidCallback onTap;

  const _ResetItemTile({
    required this.reminder,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (tone, statusColor, label) = switch (reminder.status) {
      ReminderStatus.overdue => (PillTone.overdue, context.palette.danger, 'Overdue'),
      ReminderStatus.dueSoon => (PillTone.dueSoon, context.palette.attention, context.l10n.dueSoon),
      ReminderStatus.ok => (PillTone.ok, context.palette.success, 'OK'),
    };

    return Container(
      decoration: BoxDecoration(
        color: selected ? context.palette.surfaceVariant : context.palette.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(
          color: selected ? context.palette.primary.withValues(alpha: 0.4) : context.palette.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                activeColor: context.palette.primary,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Icon(
                iconForServiceType(reminder.serviceType),
                size: 20,
                color: selected ? context.palette.primary : statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.serviceType.localizedLabel(context.l10n),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminder.lastServiceDate != null
                          ? context.l10n.lastDoneKmAgo(reminder.kmSinceService.toStringAsFixed(0))
                          : context.l10n.noPreviousServiceRecorded,
                      style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EditorialPill(label, tone: tone, filled: reminder.status == ReminderStatus.overdue),
            ],
          ),
        ),
      ),
    );
  }
}
