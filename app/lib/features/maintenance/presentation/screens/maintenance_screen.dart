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
import '../widgets/maintenance_check_row.dart';
import '../widgets/maintenance_first_time_cards.dart';
import '../widgets/maintenance_format.dart';
import '../widgets/maintenance_health_card.dart';
import '../widgets/maintenance_log_tile.dart';
import '../widgets/maintenance_settings_section.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

enum _FilterTab { all, attention, ok }

/// Maintenance home for one bike. Top to bottom: what's due (health +
/// tracked checks), the one primary action (log a service), history, and —
/// last — "Maintenance settings" holding every configuration action
/// (customize checks, odometer sync, bulk reset, km/mi, running costs).
class MaintenanceScreen extends ConsumerStatefulWidget {
  final String? bikeId;
  const MaintenanceScreen({super.key, this.bikeId});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
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

    final imperial = ref.watch(maintenanceImperialProvider);
    final isCustomizedAsync =
        ref.watch(isMaintenanceCustomizedProvider(activeBike.id));
    final hasCustomized = isCustomizedAsync.valueOrNull ?? true;

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
              _buildHeader(bikes, activeBike, imperial),
              const SizedBox(height: 14),

              // The page's one primary action.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context
                      .go('/home/maintenance/add?bikeId=${activeBike.id}'),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.logServiceTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(context.shape.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (!hasCustomized)
                MaintenanceFirstTimeCards(bike: activeBike, imperial: imperial)
              else
                _buildChecks(activeBike, imperial),
              const SizedBox(height: 24),

              _buildHistory(activeBike, imperial),
              const SizedBox(height: 28),

              MaintenanceSettingsSection(bike: activeBike),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      List<BikeEntity> bikes, BikeEntity activeBike, bool imperial) {
    return Column(
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
            Flexible(
              child: Text(
                activeBike.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary),
              ),
            ),
            Text(
              ' · ${distLabel(activeBike.currentOdometerKm, imperial)}',
              style:
                  TextStyle(fontSize: 14, color: context.palette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecks(BikeEntity activeBike, bool imperial) {
    final reminders = ref.watch(maintenanceRemindersProvider(activeBike.id));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reminders.isNotEmpty) ...[
          MaintenanceHealthCard(
              overdue: overdueCount, dueSoon: dueSoonCount, ok: okCount),
          const SizedBox(height: 18),
        ],
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
        if (reminders.isNotEmpty) ...[
          Row(
            children: [
              MaintenanceFilterChip(
                label: context.l10n.filterAll(reminders.length),
                active: _currentFilter == _FilterTab.all,
                onTap: () => setState(() => _currentFilter = _FilterTab.all),
              ),
              const SizedBox(width: 6),
              if (attentionCount > 0) ...[
                MaintenanceFilterChip(
                  label: context.l10n.filterAttention(attentionCount),
                  active: _currentFilter == _FilterTab.attention,
                  tone: PillTone.overdue,
                  onTap: () =>
                      setState(() => _currentFilter = _FilterTab.attention),
                ),
                const SizedBox(width: 6),
              ],
              MaintenanceFilterChip(
                label: context.l10n.filterOk(okCount),
                active: _currentFilter == _FilterTab.ok,
                tone: PillTone.ok,
                onTap: () => setState(() => _currentFilter = _FilterTab.ok),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (filteredReminders.isEmpty)
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
          )
        else
          for (var i = 0; i < filteredReminders.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            MaintenanceCheckRow(
              reminder: filteredReminders[i],
              imperial: imperial,
              bikeId: activeBike.id,
            ),
          ],
      ],
    );
  }

  Widget _buildHistory(BikeEntity activeBike, bool imperial) {
    final logsAsync = ref.watch(maintenanceProvider(activeBike.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EditorialLabel(context.l10n.serviceHistory),
            logsAsync.maybeWhen(
              data: (logs) {
                final totalCost = logs.fold<double>(
                    0.0, (sum, item) => sum + (item.cost ?? 0.0));
                if (totalCost <= 0) return const SizedBox.shrink();
                return Text(
                  context.l10n.total(totalCost.toStringAsFixed(0)),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textSecondary),
                );
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
            onRetry: () => ref.invalidate(maintenanceProvider(activeBike.id)),
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
            return Column(
              children: [
                for (var i = 0; i < logs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  MaintenanceLogTile(log: logs[i], imperial: imperial),
                ],
              ],
            );
          },
        ),
      ],
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
}
