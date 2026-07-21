import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/maintenance_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBike = ref.watch(activeBikeProvider);

    if (activeBike == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Maintenance')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.two_wheeler, size: 64, color: AppColors.textTertiary),
              SizedBox(height: 16),
              Text('No active bike', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    final reminders = ref.watch(maintenanceRemindersProvider(activeBike.id));
    final logsAsync = ref.watch(maintenanceProvider(activeBike.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Maintenance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/home/maintenance/add?bikeId=${activeBike.id}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bike header
            Row(
              children: [
                const Icon(Icons.two_wheeler, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(activeBike.displayName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                Text('${activeBike.totalDistanceKm.toStringAsFixed(0)} km',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 16),

            // Reminders
            if (reminders.isNotEmpty) ...[
              const Text('Service Status',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...reminders.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReminderCard(reminder: r),
                  )),
              const SizedBox(height: 20),
            ],

            // Log history
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service History',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                TextButton.icon(
                  onPressed: () =>
                      context.go('/home/maintenance/add?bikeId=${activeBike.id}'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log Service', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No service logs yet.\nTap + to add your first one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textTertiary)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogTile(log: logs[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final MaintenanceReminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final color = switch (reminder.status) {
      ReminderStatus.overdue => AppColors.danger,
      ReminderStatus.dueSoon => AppColors.warning,
      ReminderStatus.ok => AppColors.success,
    };
    final label = switch (reminder.status) {
      ReminderStatus.overdue => 'OVERDUE',
      ReminderStatus.dueSoon => 'DUE SOON',
      ReminderStatus.ok => 'OK',
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_serviceIcon(reminder.serviceType), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.serviceType.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
                Text(
                  '${reminder.kmSinceService.toStringAsFixed(0)} km since last service '
                  '(limit: ${reminder.kmLimit.toStringAsFixed(0)} km)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  IconData _serviceIcon(ServiceType type) {
    switch (type) {
      case ServiceType.oilChange: return Icons.opacity;
      case ServiceType.airFilter: return Icons.air;
      case ServiceType.chain: return Icons.link;
      case ServiceType.tire: return Icons.tire_repair;
      default: return Icons.build;
    }
  }
}

class _LogTile extends ConsumerWidget {
  final MaintenanceEntity log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.serviceType.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(log.date)} · ${log.odometerKm.toStringAsFixed(0)} km'
                  '${log.cost != null ? ' · ৳${log.cost!.toStringAsFixed(0)}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Text(log.notes!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 18),
            onPressed: () => ref.read(maintenanceProvider(log.bikeId).notifier).deleteLog(log.id),
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
