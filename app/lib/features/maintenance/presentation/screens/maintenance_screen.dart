import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/odometer_sync_sheet.dart';

const double _kmToMi = 0.621371;

String _distLabel(double km, bool imperial) {
  final value = imperial ? km * _kmToMi : km;
  return '${value.toStringAsFixed(0)} ${imperial ? 'mi' : 'km'}';
}

enum _FilterTab { all, attention, ok }

class MaintenanceScreen extends ConsumerStatefulWidget {
  final String? bikeId;
  const MaintenanceScreen({super.key, this.bikeId});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _imperial = false;
  _FilterTab _currentFilter = _FilterTab.all;
  String? _selectedBikeId;

  @override
  void initState() {
    super.initState();
    _selectedBikeId = widget.bikeId;
  }

  @override
  Widget build(BuildContext context) {
    final bikes = ref.watch(garageProvider).valueOrNull ?? [];
    final activeBike = _selectedBikeId != null
        ? bikes.where((b) => b.id == _selectedBikeId).firstOrNull
        : (widget.bikeId != null
            ? bikes.where((b) => b.id == widget.bikeId).firstOrNull
            : ref.watch(activeBikeProvider));

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
                const SizedBox(height: 8),
                Text('Add a motorcycle to your garage to track maintenance.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final reminders = ref.watch(maintenanceRemindersProvider(activeBike.id));
    final logsAsync = ref.watch(maintenanceProvider(activeBike.id));
    final isCustomizedAsync =
        ref.watch(isMaintenanceCustomizedProvider(activeBike.id));
    final hasCustomized = isCustomizedAsync.valueOrNull ?? true;

    final overdueCount =
        reminders.where((r) => r.status == ReminderStatus.overdue).length;
    final dueSoonCount =
        reminders.where((r) => r.status == ReminderStatus.dueSoon).length;
    final okCount =
        reminders.where((r) => r.status == ReminderStatus.ok).length;
    final attentionCount = overdueCount + dueSoonCount;

    final filteredReminders = switch (_currentFilter) {
      _FilterTab.all => reminders,
      _FilterTab.attention =>
        reminders.where((r) => r.status != ReminderStatus.ok).toList(),
      _FilterTab.ok =>
        reminders.where((r) => r.status == ReminderStatus.ok).toList(),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 12,
              AppDimensions.paddingMd, AppDimensions.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Bike Switcher & Units
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Maintenance', style: display(26)),
                            if (bikes.length > 1) ...[
                              const SizedBox(width: 8),
                              _buildBikeDropdown(bikes, activeBike),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (activeBike.colorValue != null) ...[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Color(activeBike.colorValue!),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              activeBike.displayName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              ' · ${_distLabel(activeBike.currentOdometerKm, _imperial)}',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
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
              const SizedBox(height: 14),

              // Action Bar: Odo Sync, Configure, Log Service
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => OdometerSyncSheet.show(context, activeBike),
                      icon: const Icon(Icons.speed, size: 16),
                      label: const Text('Sync Odo',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                          '/home/maintenance/configure?bikeId=${activeBike.id}'),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Customize',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(
                          '/home/maintenance/add?bikeId=${activeBike.id}'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Log',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unconfigured Prompt Banner
              if (!hasCustomized) ...[
                _buildUnconfiguredBanner(activeBike),
                const SizedBox(height: 16),
              ],

              // Health Status Overview Card
              _buildHealthOverviewCard(
                  overdueCount, dueSoonCount, okCount, reminders.length),
              const SizedBox(height: 18),

              // Tracked Checks Section Header & Filter Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const EditorialLabel('Tracked checks'),
                  Text(
                    '${reminders.length} monitored',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Chips
              if (reminders.isNotEmpty) ...[
                Row(
                  children: [
                    _FilterChip(
                      label: 'All (${reminders.length})',
                      active: _currentFilter == _FilterTab.all,
                      onTap: () => setState(() => _currentFilter = _FilterTab.all),
                    ),
                    const SizedBox(width: 6),
                    if (attentionCount > 0) ...[
                      _FilterChip(
                        label: 'Attention ($attentionCount)',
                        active: _currentFilter == _FilterTab.attention,
                        tone: PillTone.overdue,
                        onTap: () => setState(
                            () => _currentFilter = _FilterTab.attention),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _FilterChip(
                      label: 'OK ($okCount)',
                      active: _currentFilter == _FilterTab.ok,
                      tone: PillTone.ok,
                      onTap: () => setState(() => _currentFilter = _FilterTab.ok),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Checks List
              if (filteredReminders.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      reminders.isEmpty
                          ? 'No checks tracked yet. Tap "Customize" above to select checks.'
                          : 'No checks matching this filter.',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                for (var i = 0; i < filteredReminders.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _CheckRow(
                    reminder: filteredReminders[i],
                    imperial: _imperial,
                    bikeId: activeBike.id,
                  ),
                ],
              ],
              const SizedBox(height: 24),

              // Service History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const EditorialLabel('Service history'),
                  logsAsync.maybeWhen(
                    data: (logs) {
                      final totalCost = logs.fold<double>(
                          0.0, (sum, item) => sum + (item.cost ?? 0.0));
                      if (totalCost > 0) {
                        return Text(
                          'Total: ৳${totalCost.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              logsAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) =>
                    Text('$e', style: TextStyle(color: AppColors.danger)),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.history,
                                color: AppColors.textTertiary, size: 36),
                            const SizedBox(height: 8),
                            Text('No service records logged yet.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              'When you service your bike, log it here to reset intervals.',
                              style: TextStyle(
                                  color: AppColors.textTertiary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _LogTile(
                      log: logs[i],
                      imperial: _imperial,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBikeDropdown(List<BikeEntity> bikes, BikeEntity activeBike) {
    return PopupMenuButton<String>(
      tooltip: 'Switch bike',
      color: AppColors.surfaceVariant,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Switch',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
      onSelected: (id) => setState(() => _selectedBikeId = id),
      itemBuilder: (ctx) => bikes
          .map((b) => PopupMenuItem<String>(
                value: b.id,
                child: Row(
                  children: [
                    if (b.colorValue != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(b.colorValue!),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(b.displayName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: b.id == activeBike.id
                                ? FontWeight.w700
                                : FontWeight.normal)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildUnconfiguredBanner(BikeEntity bike) {
    return EditorialCard(
      radius: AppDimensions.radiusLg,
      padding: const EdgeInsets.all(12),
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tune, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customize Tracked Items', style: display(13)),
                const SizedBox(height: 2),
                Text(
                  'Choose which checks and intervals matter for ${bike.displayName}.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => context
                .push('/home/maintenance/configure?bikeId=${bike.id}'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthOverviewCard(
      int overdue, int dueSoon, int ok, int total) {
    if (total == 0) return const SizedBox.shrink();

    final Color statusColor;
    final String statusTitle;
    final String statusSubtitle;
    final IconData statusIcon;

    if (overdue > 0) {
      statusColor = AppColors.danger;
      statusTitle = '$overdue ${overdue == 1 ? 'Service Overdue' : 'Services Overdue'}';
      statusSubtitle = 'Immediate maintenance attention recommended';
      statusIcon = Icons.warning_amber_rounded;
    } else if (dueSoon > 0) {
      statusColor = AppColors.attention;
      statusTitle = '$dueSoon ${dueSoon == 1 ? 'Service Due Soon' : 'Services Due Soon'}';
      statusSubtitle = 'Upcoming scheduled maintenance';
      statusIcon = Icons.schedule;
    } else {
      statusColor = AppColors.success;
      statusTitle = 'All Systems Nominal';
      statusSubtitle = 'All $total tracked components in good health';
      statusIcon = Icons.verified_outlined;
    }

    return EditorialCard(
      radius: AppDimensions.radiusLg,
      padding: const EdgeInsets.all(14),
      borderColor: statusColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusTitle,
                        style: display(15, letterSpacing: 0)),
                    const SizedBox(height: 2),
                    Text(statusSubtitle,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Health Distribution Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                if (overdue > 0)
                  Expanded(
                    flex: overdue,
                    child: Container(height: 6, color: AppColors.danger),
                  ),
                if (dueSoon > 0)
                  Expanded(
                    flex: dueSoon,
                    child: Container(height: 6, color: AppColors.attention),
                  ),
                if (ok > 0)
                  Expanded(
                    flex: ok,
                    child: Container(height: 6, color: AppColors.success),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricPill('Overdue', overdue, AppColors.danger),
              _metricPill('Due Soon', dueSoon, AppColors.attention),
              _metricPill('Good', ok, AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: count > 0 ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final PillTone? tone;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = active
        ? (tone == PillTone.overdue
            ? AppColors.danger.withValues(alpha: 0.2)
            : (tone == PillTone.ok
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.ink))
        : Colors.transparent;

    final textColor = active
        ? (tone == PillTone.overdue
            ? AppColors.danger
            : (tone == PillTone.ok
                ? AppColors.success
                : AppColors.onInk))
        : AppColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: active ? Colors.transparent : AppColors.border,
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

class _CheckRow extends StatelessWidget {
  final MaintenanceReminder reminder;
  final bool imperial;
  final String bikeId;

  const _CheckRow({
    required this.reminder,
    required this.imperial,
    required this.bikeId,
  });

  IconData _iconForService(ServiceType type) {
    switch (type) {
      case ServiceType.oilChange:
      case ServiceType.oilFilter:
        return Icons.opacity;
      case ServiceType.airFilter:
        return Icons.air;
      case ServiceType.chain:
      case ServiceType.chainTension:
        return Icons.link;
      case ServiceType.tire:
        return Icons.tire_repair;
      case ServiceType.frontDiscPads:
      case ServiceType.rearDrumPads:
      case ServiceType.brakeFluid:
      case ServiceType.brakeRotors:
        return Icons.disc_full;
      case ServiceType.sparkPlug:
        return Icons.electric_bolt;
      case ServiceType.battery:
        return Icons.battery_charging_full;
      case ServiceType.radiatorCoolant:
        return Icons.water_drop;
      case ServiceType.clutchCable:
      case ServiceType.throttleCables:
        return Icons.tune;
      case ServiceType.valveClearance:
        return Icons.build;
      case ServiceType.suspension:
      case ServiceType.forkSeals:
        return Icons.vertical_align_center;
      case ServiceType.wheelBearings:
      case ServiceType.driveBelt:
        return Icons.album;
      case ServiceType.custom:
        return Icons.handyman;
    }
  }

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
              Icon(
                _iconForService(reminder.serviceType),
                size: 18,
                color: barColor,
              ),
              const SizedBox(width: 8),
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
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: isOverdue ? FontWeight.w700 : FontWeight.normal,
                      color: isOverdue ? AppColors.danger : AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          EditorialProgress(progress, color: barColor, height: 5),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reminder.lastServiceDate != null
                    ? 'Last done: ${_formatDate(reminder.lastServiceDate!)}'
                    : 'No previous service recorded',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              GestureDetector(
                onTap: () => context.go(
                    '/home/maintenance/add?bikeId=$bikeId&serviceType=${reminder.serviceType.name}'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 12, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text('Log',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
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
                Text(log.displayLabel, style: display(14, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(log.date)} · ${_distLabel(log.odometerKm, imperial)}'
                  '${log.cost != null ? ' · ৳${log.cost!.toStringAsFixed(0)}' : ''}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(log.notes!,
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 18),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text('Delete Log', style: display(16)),
                  content: Text(
                    'Are you sure you want to delete this ${log.displayLabel} record?',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Cancel',
                          style: TextStyle(color: AppColors.textTertiary)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref
                    .read(maintenanceProvider(log.bikeId).notifier)
                    .deleteLog(log.id);
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
