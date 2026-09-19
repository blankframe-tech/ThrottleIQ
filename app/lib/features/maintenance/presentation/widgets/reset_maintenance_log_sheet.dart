import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import 'edit_maintenance_check_sheet.dart' show iconForServiceType;

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
        title: const Text('Reset selected items?'),
        content: Text(
          _selected.length == 1
              ? 'This logs "${_selected.first.label}" as serviced today at the '
                  "bike's current odometer, resetting its due date. Past "
                  'history is kept.'
              : 'This logs ${_selected.length} items as serviced today at the '
                  "bike's current odometer, resetting their due dates. Past "
                  'history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
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
        backgroundColor: AppColors.surfaceVariant,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 1
                    ? '1 item reset to serviced today.'
                    : '$count items reset to serviced today.',
                style: TextStyle(color: AppColors.textPrimary),
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
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.border),
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
                color: AppColors.border,
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
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restart_alt, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset Service Log', style: display(18)),
                    Text(
                      'Tick what you just serviced on ${widget.bike.displayName}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selected items are logged as serviced today at the current '
            'odometer, resetting their due date. Nothing is deleted.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (reminders.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No tracked checks yet. Set some up under "Customize" first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _selected.addAll(reminders.map((r) => r.serviceType))),
                  child: const Text('Select All', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
                  child: Text('Clear',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ),
                const Spacer(),
                Text('${_selected.length} of ${reminders.length} selected',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
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
                            ? 'Select items to reset'
                            : 'Reset ${_selected.length} Item${_selected.length == 1 ? '' : 's'}',
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
      ReminderStatus.overdue => (PillTone.overdue, AppColors.danger, 'Overdue'),
      ReminderStatus.dueSoon => (PillTone.dueSoon, AppColors.attention, 'Due soon'),
      ReminderStatus.ok => (PillTone.ok, AppColors.success, 'OK'),
    };

    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceVariant : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Icon(
                iconForServiceType(reminder.serviceType),
                size: 20,
                color: selected ? AppColors.primary : statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.serviceType.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminder.lastServiceDate != null
                          ? 'Last done ${reminder.kmSinceService.toStringAsFixed(0)} km ago'
                          : 'No previous service recorded',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
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
