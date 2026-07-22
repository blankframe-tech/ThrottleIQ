import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
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
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.two_wheeler, size: 56, color: AppColors.textTertiary),
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
              Text('Maintenance', style: display(28)),
              const SizedBox(height: 4),
              Text(
                '${activeBike.displayName} · ${activeBike.totalDistanceKm.toStringAsFixed(0)} km',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Checks
              if (reminders.isNotEmpty) ...[
                const EditorialLabel('Service checks'),
                const SizedBox(height: 10),
                EditorialCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMd, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < reminders.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CheckRow(reminder: reminders[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Add custom check (dashed)
              _DashedAddButton(
                label: 'Log a service',
                onTap: () =>
                    context.go('/home/maintenance/add?bikeId=${activeBike.id}'),
              ),
              const SizedBox(height: 24),

              // History
              const EditorialLabel('Service history'),
              const SizedBox(height: 10),
              logsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) =>
                    Text('$e', style: const TextStyle(color: AppColors.danger)),
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Padding(
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
                    itemBuilder: (_, i) => _LogTile(log: logs[i]),
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

class _CheckRow extends StatelessWidget {
  final MaintenanceReminder reminder;
  const _CheckRow({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final (tone, barColor, label) = switch (reminder.status) {
      ReminderStatus.overdue => (PillTone.overdue, AppColors.danger, 'Overdue'),
      ReminderStatus.dueSoon => (PillTone.dueSoon, AppColors.attention, 'Due soon'),
      ReminderStatus.ok => (PillTone.ok, AppColors.primary, 'OK'),
    };
    final progress = reminder.kmLimit > 0
        ? (reminder.kmSinceService / reminder.kmLimit).clamp(0.0, 1.0)
        : 0.0;
    final kmLeft = reminder.kmLimit - reminder.kmSinceService;
    final rightText = kmLeft >= 0
        ? '${kmLeft.toStringAsFixed(0)} km left'
        : '${(-kmLeft).toStringAsFixed(0)} km over';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(reminder.serviceType.label,
                    style: display(15, letterSpacing: 0)),
              ),
              EditorialPill(label, tone: tone, filled: false),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Every ${reminder.kmLimit.toStringAsFixed(0)} km',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(rightText,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          EditorialProgress(progress, color: barColor),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DashedAddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label,
                style: display(14, letterSpacing: 0, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  final MaintenanceEntity log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditorialCard(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.serviceType.label, style: display(14, letterSpacing: 0)),
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
