import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/edit_maintenance_check_sheet.dart';
import '../widgets/odometer_sync_sheet.dart';
import '../widgets/reset_maintenance_log_sheet.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../service_type_l10n.dart';

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

  /// Back-only app bar when this screen was pushed (from bike detail or the
  /// garage card) rather than opened as the Maintenance tab — there was no
  /// way back otherwise short of the system gesture (grill §3.2.3).
  /// Untitled because the body's own header already says "Maintenance".
  PreferredSizeWidget? _backBar(BuildContext context) => context.canPop()
      ? AppBar(backgroundColor: context.palette.background, toolbarHeight: 48)
      : null;

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
        backgroundColor: context.palette.background,
        appBar: _backBar(context),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.two_wheeler, size: 56, color: context.palette.textTertiary),
                const SizedBox(height: 16),
                Text(context.l10n.noActiveBike, style: display(context, 20)),
                const SizedBox(height: 8),
                Text(context.l10n.addMotorcycleGarageTrack,
                    style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
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
      backgroundColor: context.palette.background,
      appBar: _backBar(context),
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
                            Text(context.l10n.maintenance, style: display(context, 26)),
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
                                  color: context.palette.textPrimary),
                            ),
                            Text(
                              ' · ${_distLabel(activeBike.currentOdometerKm, _imperial)}',
                              style: TextStyle(
                                  fontSize: 14, color: context.palette.textSecondary),
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
                      label: Text(context.l10n.syncOdo,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: context.palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.shape.radiusMd),
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
                      label: Text(context.l10n.customize,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: context.palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.shape.radiusMd),
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
                      label: Text(context.l10n.log,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.shape.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: context.l10n.resetServiceLog,
                    child: OutlinedButton(
                      onPressed: () =>
                          ResetMaintenanceLogSheet.show(context, activeBike),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(40, 40),
                        side: BorderSide(color: context.palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.shape.radiusMd),
                        ),
                      ),
                      child: const Icon(Icons.restart_alt, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // If not customized yet, display first-time setup cards.
              if (!hasCustomized) ...[
                _FirstTimeMaintenanceCards(
                  bike: activeBike,
                  imperial: _imperial,
                ),
              ] else ...[
                // Health Status Overview Card
                _buildHealthOverviewCard(
                    overdueCount, dueSoonCount, okCount, reminders.length),
                const SizedBox(height: 18),

                // Tracked Checks Section Header & Filter Tabs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    EditorialLabel(context.l10n.trackedChecks),
                    Text(
                      context.l10n.monitored(reminders.length),
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Filter Chips
                if (reminders.isNotEmpty) ...[
                  Row(
                    children: [
                      _FilterChip(
                        label: context.l10n.filterAll(reminders.length),
                        active: _currentFilter == _FilterTab.all,
                        onTap: () => setState(() => _currentFilter = _FilterTab.all),
                      ),
                      const SizedBox(width: 6),
                      if (attentionCount > 0) ...[
                        _FilterChip(
                          label: context.l10n.filterAttention(attentionCount),
                          active: _currentFilter == _FilterTab.attention,
                          tone: PillTone.overdue,
                          onTap: () => setState(
                              () => _currentFilter = _FilterTab.attention),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _FilterChip(
                        label: context.l10n.filterOk(okCount),
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
                            ? context.l10n.noChecksTrackedYet
                            : context.l10n.noChecksMatchingThis,
                        style: TextStyle(color: context.palette.textTertiary, fontSize: 13),
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
              ],
              const SizedBox(height: 24),

              // Service History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EditorialLabel(context.l10n.serviceHistory),
                  logsAsync.maybeWhen(
                    data: (logs) {
                      final totalCost = logs.fold<double>(
                          0.0, (sum, item) => sum + (item.cost ?? 0.0));
                      if (totalCost > 0) {
                        return Text(
                          context.l10n.total(totalCost.toStringAsFixed(0)),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textSecondary),
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
                    child: CircularProgressIndicator(color: context.palette.primary)),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () =>
                      ref.invalidate(maintenanceProvider(activeBike.id)),
                ),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.history,
                                color: context.palette.textTertiary, size: 36),
                            const SizedBox(height: 8),
                            Text(context.l10n.noServiceRecordsLogged,
                                style: TextStyle(
                                    color: context.palette.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.whenServiceBikeLog,
                              style: TextStyle(
                                  color: context.palette.textTertiary, fontSize: 11),
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
      tooltip: context.l10n.switchBike,
      color: context.palette.surfaceVariant,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.shape.radiusSm),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.switchAction,
                style: TextStyle(fontSize: 11, color: context.palette.textSecondary)),
            Icon(Icons.arrow_drop_down, size: 16, color: context.palette.textSecondary),
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

  Widget _buildHealthOverviewCard(
      int overdue, int dueSoon, int ok, int total) {
    if (total == 0) return const SizedBox.shrink();

    final Color statusColor;
    final String statusTitle;
    final String statusSubtitle;
    final IconData statusIcon;

    if (overdue > 0) {
      statusColor = context.palette.danger;
      statusTitle = '$overdue ${overdue == 1 ? 'Service Overdue' : 'Services Overdue'}';
      statusSubtitle = context.l10n.immediateMaintenanceAttentionRecommended;
      statusIcon = Icons.warning_amber_rounded;
    } else if (dueSoon > 0) {
      statusColor = context.palette.attention;
      statusTitle = '$dueSoon ${dueSoon == 1 ? 'Service Due Soon' : 'Services Due Soon'}';
      statusSubtitle = context.l10n.upcomingScheduledMaintenance;
      statusIcon = Icons.schedule;
    } else {
      statusColor = context.palette.success;
      statusTitle = context.l10n.allSystemsNominal;
      statusSubtitle = context.l10n.allTrackedComponentsGood(total);
      statusIcon = Icons.verified_outlined;
    }

    return EditorialCard(
      radius: context.shape.radiusLg,
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
                        style: display(context, 15, letterSpacing: 0)),
                    const SizedBox(height: 2),
                    Text(statusSubtitle,
                        style: TextStyle(
                            fontSize: 11, color: context.palette.textSecondary)),
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
                    child: Container(height: 6, color: context.palette.danger),
                  ),
                if (dueSoon > 0)
                  Expanded(
                    flex: dueSoon,
                    child: Container(height: 6, color: context.palette.attention),
                  ),
                if (ok > 0)
                  Expanded(
                    flex: ok,
                    child: Container(height: 6, color: context.palette.success),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricPill('Overdue', overdue, context.palette.danger),
              _metricPill(context.l10n.dueSoonTitle, dueSoon, context.palette.attention),
              _metricPill('Good', ok, context.palette.success),
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
            color: count > 0 ? context.palette.textSecondary : context.palette.textTertiary,
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

class _UnitToggle extends StatelessWidget {
  final bool imperial;
  final ValueChanged<bool> onChanged;
  const _UnitToggle({required this.imperial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.shape.radiusFull),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UnitSegment(label: context.l10n.distanceStatLabel, active: !imperial, onTap: () => onChanged(false)),
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
          color: active ? context.palette.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? context.palette.onInk : context.palette.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _FirstTimeMaintenanceCards extends ConsumerStatefulWidget {
  final BikeEntity bike;
  final bool imperial;

  const _FirstTimeMaintenanceCards({
    required this.bike,
    required this.imperial,
  });

  @override
  ConsumerState<_FirstTimeMaintenanceCards> createState() =>
      _FirstTimeMaintenanceCardsState();
}

class _FirstTimeMaintenanceCardsState
    extends ConsumerState<_FirstTimeMaintenanceCards> {
  static const _catalogTypes = [
    ServiceType.fuel,
    ServiceType.oilChange,
    ServiceType.chain,
    ServiceType.tire,
    ServiceType.frontDiscPads,
    ServiceType.airFilter,
    ServiceType.battery,
    ServiceType.sparkPlug,
  ];

  late List<MaintenanceConfigEntity> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(maintenanceConfigProvider(widget.bike.id)).valueOrNull ?? [];
    final map = {for (final e in existing) e.serviceType: e};

    _items = _catalogTypes.map((type) {
      if (map.containsKey(type)) {
        return map[type]!;
      }
      final isEssential = type == ServiceType.fuel ||
          type == ServiceType.oilChange ||
          type == ServiceType.chain ||
          type == ServiceType.tire;
      return MaintenanceConfigEntity(
        bikeId: widget.bike.id,
        serviceType: type,
        intervalKm: type.defaultIntervalKm,
        isEnabled: isEssential,
      );
    }).toList();
  }

  void _toggle(ServiceType type) {
    setState(() {
      _items = _items.map((it) {
        if (it.serviceType == type) {
          return it.copyWith(isEnabled: !it.isEnabled);
        }
        return it;
      }).toList();
    });
  }

  void _selectEssentials() {
    setState(() {
      _items = _items.map((it) {
        final isEssential = it.serviceType == ServiceType.fuel ||
            it.serviceType == ServiceType.oilChange ||
            it.serviceType == ServiceType.chain ||
            it.serviceType == ServiceType.tire;
        return it.copyWith(isEnabled: isEssential);
      }).toList();
    });
  }

  void _selectAll() {
    setState(() {
      _items = _items.map((it) => it.copyWith(isEnabled: true)).toList();
    });
  }

  void _clearAll() {
    setState(() {
      _items = _items.map((it) => it.copyWith(isEnabled: false)).toList();
    });
  }

  Future<void> _editItem(MaintenanceConfigEntity item) async {
    final updated = await EditMaintenanceCheckSheet.show(
      context,
      config: item,
      persistImmediately: false,
    );
    if (updated != null && mounted) {
      setState(() {
        _items = _items.map((it) {
          if (it.serviceType == updated.serviceType) {
            return updated;
          }
          return it;
        }).toList();
      });
    }
  }

  Future<void> _startTracking() async {
    setState(() => _saving = true);
    await ref
        .read(maintenanceConfigProvider(widget.bike.id).notifier)
        .saveConfigs(_items);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _items.where((i) => i.isEnabled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome card
        EditorialCard(
          radius: context.shape.radiusLg,
          padding: const EdgeInsets.all(16),
          borderColor: context.palette.primary.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.palette.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.two_wheeler,
                        color: context.palette.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.whatWouldLikeMaintain,
                      style: display(context, 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.notEveryoneWantsTrack(widget.bike.displayName),
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: Icon(Icons.star_outline,
                        size: 14, color: context.palette.primary),
                    label: Text(context.l10n.essentials4,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _selectEssentials,
                    backgroundColor: context.palette.surfaceVariant,
                    side: BorderSide(color: context.palette.border),
                  ),
                  ActionChip(
                    avatar: Icon(Icons.done_all,
                        size: 14, color: context.palette.textSecondary),
                    label: Text(context.l10n.all8Items,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _selectAll,
                    backgroundColor: context.palette.surfaceVariant,
                    side: BorderSide(color: context.palette.border),
                  ),
                  ActionChip(
                    avatar: Icon(Icons.clear,
                        size: 14, color: context.palette.textTertiary),
                    label: Text(context.l10n.clear,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _clearAll,
                    backgroundColor: context.palette.surfaceVariant,
                    side: BorderSide(color: context.palette.border),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Curated Setup Cards
        for (final item in _items) ...[
          _buildFirstTimeCard(item),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),

        // Action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _startTracking,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              _saving
                  ? context.l10n.savingPreferences
                  : (enabledCount > 0
                      ? context.l10n.startTrackingItems(enabledCount)
                      : context.l10n.savePreferences),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push(
                '/home/maintenance/configure?bikeId=${widget.bike.id}'),
            icon: const Icon(Icons.tune, size: 14),
            label: Text(
              context.l10n.seeAll20Checks,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstTimeCard(MaintenanceConfigEntity item) {
    final isSelected = item.isEnabled;
    final icon = iconForServiceType(item.serviceType);

    return EditorialCard(
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: isSelected
          ? context.palette.primary.withValues(alpha: 0.5)
          : context.palette.border,
      color: isSelected
          ? context.palette.surfaceVariant.withValues(alpha: 0.7)
          : context.palette.surface.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => _toggle(item.serviceType),
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggle(item.serviceType),
                  activeColor: context.palette.primary,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? context.palette.primary : context.palette.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceType.localizedLabel(context.l10n),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? context.palette.textPrimary
                              : context.palette.textTertiary,
                        ),
                      ),
                      Text(
                        item.serviceType.localizedDescription(context.l10n),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.palette.textTertiary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _editItem(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius:
                          BorderRadius.circular(context.shape.radiusFull),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.intervalKm.toStringAsFixed(0)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? context.palette.primary
                                : context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.edit_outlined,
                            size: 11,
                            color: isSelected
                                ? context.palette.primary
                                : context.palette.textTertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 12, color: context.palette.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.notes!.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends ConsumerWidget {
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
      case ServiceType.fuel:
        return Icons.local_gas_station;
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
        ? '${_distLabel(kmLeft, imperial)} left'
        : '${_distLabel(-kmLeft, imperial)} over';

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
                _iconForService(reminder.serviceType),
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
              Text(context.l10n.intervalEvery(_distLabel(reminder.kmLimit, imperial)),
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
                    ? context.l10n.lastDone(_formatDate(reminder.lastServiceDate!))
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
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.localizedDisplayLabel(context.l10n), style: display(context, 14, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(log.date)} · ${_distLabel(log.odometerKm, imperial)}'
                  '${log.cost != null ? ' · ৳${log.cost!.toStringAsFixed(0)}' : ''}',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(log.notes!,
                      style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.delete,
            icon: Icon(Icons.delete_outline, color: context.palette.textTertiary, size: 18),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ctx.palette.surface,
                  title: Text(ctx.l10n.deleteLog, style: display(ctx, 16)),
                  content: Text(
                    ctx.l10n.sureWantDeleteThis(log.localizedDisplayLabel(ctx.l10n)),
                    style: TextStyle(fontSize: 13, color: ctx.palette.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(ctx.l10n.cancelAction,
                          style: TextStyle(color: ctx.palette.textTertiary)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ctx.palette.danger),
                      child: Text(ctx.l10n.delete),
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
