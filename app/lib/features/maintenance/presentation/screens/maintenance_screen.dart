import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../providers/maintenance_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';

const double _kmToMi = 0.621371;

String _distLabel(double km, bool imperial) {
  final value = imperial ? km * _kmToMi : km;
  return '${value.toStringAsFixed(0)} ${imperial ? 'mi' : 'km'}';
}

class MaintenanceScreen extends ConsumerStatefulWidget {
  /// The bike to show service history/reminders for. Falls back to the
  /// active bike when null — preserves the bottom-nav "Service" tab's
  /// existing behavior while letting a specific bike card in the garage
  /// (which knows its own id) open that bike's maintenance instead of
  /// whichever bike happens to be active.
  final String? bikeId;
  const MaintenanceScreen({super.key, this.bikeId});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _imperial = false;

  @override
  Widget build(BuildContext context) {
    final bikes = ref.watch(garageProvider).valueOrNull ?? [];
    final activeBike = widget.bikeId != null
        ? bikes.where((b) => b.id == widget.bikeId).firstOrNull
        : ref.watch(activeBikeProvider);

    if (activeBike == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.two_wheeler, size: 56, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('No active bike', style: display(20)),
              ],
            ),
          ),
        ),
      );
    }

    final reminders = ref.watch(maintenanceRemindersProvider(activeBike.id));
    final logsAsync = ref.watch(maintenanceProvider(activeBike.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 12,
              AppDimensions.paddingMd, AppDimensions.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Maintenance', style: display(28)),
                        const SizedBox(height: 4),
                        Text(
                          '${activeBike.displayName} · '
                          '${_distLabel(activeBike.currentOdometerKm, _imperial)}',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _UnitToggle(
                    imperial: _imperial,
                    onChanged: (v) => setState(() => _imperial = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'These checks track themselves from your ride distance — '
                'log a service below once you\'ve had one done.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textTertiary, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Checks
              if (reminders.isNotEmpty) ...[
                const EditorialLabel('Service checks'),
                const SizedBox(height: 10),
                for (var i = 0; i < reminders.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _CheckRow(reminder: reminders[i], imperial: _imperial),
                ],
                const SizedBox(height: 12),
              ],

              // Add custom check (dashed)
              DashedAddButton(
                label: 'Log a service',
                onTap: () =>
                    context.go('/home/maintenance/add?bikeId=${activeBike.id}'),
              ),
              const SizedBox(height: 24),

              // History
              const EditorialLabel('Service history'),
              const SizedBox(height: 10),
              logsAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) =>
                    Text('$e', style: TextStyle(color: AppColors.danger)),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No service logs yet.',
                            style: TextStyle(color: AppColors.textTertiary)),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _LogTile(log: logs[i], imperial: _imperial),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// km/mi segmented toggle — display-only on this screen (converts the
/// numbers shown here; there's no app-wide unit preference to persist to).
class _UnitToggle extends StatelessWidget {
  final bool imperial;
  final ValueChanged<bool> onChanged;
  const _UnitToggle({required this.imperial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UnitSegment(label: 'km', active: !imperial, onTap: () => onChanged(false)),
          _UnitSegment(label: 'mi', active: imperial, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _UnitSegment extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _UnitSegment({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? AppColors.onInk : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Each check is its own bordered card (not rows sharing one card) — cards
/// stay neutral-bordered at ok/due-soon, and only flip to a colored border +
/// a filled (rather than outline) status pill once overdue, so the one
/// thing that actually needs attention is what visually stands out.
class _CheckRow extends StatelessWidget {
  final MaintenanceReminder reminder;
  final bool imperial;
  const _CheckRow({required this.reminder, required this.imperial});

  @override
  Widget build(BuildContext context) {
    final (tone, barColor, label) = switch (reminder.status) {
      ReminderStatus.overdue => (PillTone.overdue, AppColors.danger, 'Overdue'),
      ReminderStatus.dueSoon => (PillTone.dueSoon, AppColors.attention, 'Due soon'),
      ReminderStatus.ok => (PillTone.ok, AppColors.success, 'OK'),
    };
    final isOverdue = reminder.status == ReminderStatus.overdue;
    final progress = reminder.kmLimit > 0
        ? (reminder.kmSinceService / reminder.kmLimit).clamp(0.0, 1.0)
        : 0.0;
    final kmLeft = reminder.kmLimit - reminder.kmSinceService;
    final rightText = kmLeft >= 0
        ? '${_distLabel(kmLeft, imperial)} left'
        : '${_distLabel(-kmLeft, imperial)} over';

    return EditorialCard(
      radius: AppDimensions.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      borderColor: isOverdue ? AppColors.danger : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(reminder.serviceType.label,
                    style: display(15, letterSpacing: 0)),
              ),
              EditorialPill(label, tone: tone, filled: isOverdue),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Every ${_distLabel(reminder.kmLimit, imperial)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(rightText,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          EditorialProgress(progress, color: barColor, height: 5),
        ],
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  final MaintenanceEntity log;
  final bool imperial;
  const _LogTile({required this.log, required this.imperial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditorialCard(
      radius: AppDimensions.radiusLg,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // displayLabel, not serviceType.label — a custom log shows the
                // name the rider gave it instead of the word "Custom".
                Text(log.displayLabel, style: display(14, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(log.date)} · ${_distLabel(log.odometerKm, imperial)}'
                  '${log.cost != null ? ' · ৳${log.cost!.toStringAsFixed(0)}' : ''}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Text(log.notes!,
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 18),
            onPressed: () =>
                ref.read(maintenanceProvider(log.bikeId).notifier).deleteLog(log.id),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
