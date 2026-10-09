import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/service_visit.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/forecast_strip.dart';
import '../widgets/maintenance_check_row.dart';
import '../widgets/maintenance_format.dart';
import '../widgets/maintenance_log_tile.dart';
import '../widgets/maintenance_settings_section.dart';
import '../widgets/money_card.dart';
import '../widgets/paperwork_card.dart';
import '../widgets/precheck_sheet.dart';
import '../widgets/up_next_card.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

/// Maintenance home for one bike — a forecast, not a checklist. Top to
/// bottom: what's next (hero), what's coming (60-day strip), every check
/// grouped by urgency, the weekly quick check, history as visits, money,
/// paperwork, and settings last. "Log a visit" stays on screen throughout.
class MaintenanceScreen extends ConsumerStatefulWidget {
  final String? bikeId;
  const MaintenanceScreen({super.key, this.bikeId});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  String? _selectedBikeId;
  bool _showAllGood = false;
  bool _showUnknown = false;
  int _historyShown = 5;

  @override
  void initState() {
    super.initState();
    _selectedBikeId = widget.bikeId;
  }

  /// A notification tap (or garage link) for another bike while this page
  /// is already open arrives as a new [widget.bikeId] on the same state.
  @override
  void didUpdateWidget(MaintenanceScreen old) {
    super.didUpdateWidget(old);
    if (widget.bikeId != null && widget.bikeId != old.bikeId) {
      _selectedBikeId = widget.bikeId;
    }
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
                Icon(Icons.two_wheeler,
                    size: 56, color: context.palette.textTertiary),
                const SizedBox(height: 16),
                Text(context.l10n.noActiveBike, style: display(context, 20)),
                const SizedBox(height: 8),
                Text(context.l10n.addMotorcycleGarageTrack,
                    style: TextStyle(
                        color: context.palette.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final imperial = ref.watch(maintenanceImperialProvider);
    final profile =
        ref.watch(maintenanceProfileProvider(activeBike.id)).valueOrNull;
    final customized =
        ref.watch(isMaintenanceCustomizedProvider(activeBike.id)).valueOrNull ??
            true;
    // Riders who customised checks before setup existed are not sent back
    // through it; the setup card is for bikes with neither.
    final needsSetup = profile?.onboardedAt == null && !customized;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: _backBar(context),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('logVisitFab'),
        onPressed: () =>
            context.push('/home/maintenance/add?bikeId=${activeBike.id}'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.logVisitTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMd, 12, AppDimensions.paddingMd, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(bikes, activeBike, imperial),
              const SizedBox(height: 14),
              if (needsSetup) ...[
                _SetupCard(bike: activeBike),
                const SizedBox(height: 18),
              ],
              UpNextCard(bikeId: activeBike.id, imperial: imperial),
              const SizedBox(height: 18),
              ForecastStrip(
                bikeId: activeBike.id,
                forecasts:
                    ref.watch(maintenanceForecastProvider(activeBike.id)),
              ),
              const SizedBox(height: 14),
              _buildChecks(activeBike, imperial),
              const SizedBox(height: 20),
              PrecheckCard(bikeId: activeBike.id),
              const SizedBox(height: 24),
              _buildHistory(activeBike, imperial),
              const SizedBox(height: 24),
              MoneyCard(bikeId: activeBike.id, imperial: imperial),
              const SizedBox(height: 12),
              EditorialCard(
                key: const Key('maintenanceFuelLink'),
                radius: context.shape.radiusLg,
                padding: const EdgeInsets.all(14),
                onTap: () => context
                    .push('/home/maintenance/fuel?bikeId=${activeBike.id}'),
                child: Row(
                  children: [
                    Icon(Icons.local_gas_station_outlined,
                        color: context.palette.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(context.l10n.fuelLogTitle,
                          style: display(context, 16, letterSpacing: 0)),
                    ),
                    Icon(Icons.chevron_right,
                        color: context.palette.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PaperworkCard(bikeId: activeBike.id),
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
              ' · ${distLabelLong(activeBike.currentOdometerKm, imperial)}',
              style:
                  TextStyle(fontSize: 14, color: context.palette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecks(BikeEntity bike, bool imperial) {
    final l10n = context.l10n;
    final forecasts = ref.watch(maintenanceForecastProvider(bike.id));
    final issues =
        ref.watch(precheckIssuesProvider(bike.id)).valueOrNull ?? const [];
    final now = DateTime.now();

    final attention = forecasts.where((f) => f.needsAttention).toList();
    final comingUp = forecasts
        .where((f) =>
            f.status == ReminderStatus.ok &&
            (f.daysUntilDue(now) ?? 9999) <= ForecastStrip.horizonDays)
        .toList();
    final comingKeys = comingUp.map((f) => f.key).toSet();
    final allGood = forecasts
        .where(
            (f) => f.status == ReminderStatus.ok && !comingKeys.contains(f.key))
        .toList();
    final unknown =
        forecasts.where((f) => f.status == ReminderStatus.unknown).toList();

    if (forecasts.isEmpty && issues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(l10n.noChecksTrackedYet,
              style:
                  TextStyle(color: context.palette.textTertiary, fontSize: 13)),
        ),
      );
    }

    Widget rows(List<CheckForecast> list) => Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              MaintenanceCheckRow(
                  forecast: list[i], imperial: imperial, bikeId: bike.id),
            ],
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attention.isNotEmpty || issues.isNotEmpty) ...[
          _GroupHeader(
              label: l10n.groupNeedsAttention(attention.length + issues.length),
              color: context.palette.danger),
          for (final issue in issues) ...[
            PrecheckIssueRow(issue: issue),
            const SizedBox(height: 8),
          ],
          rows(attention),
          const SizedBox(height: 18),
        ],
        if (comingUp.isNotEmpty) ...[
          _GroupHeader(label: l10n.groupComingUp(comingUp.length)),
          rows(comingUp),
          const SizedBox(height: 18),
        ],
        if (allGood.isNotEmpty) ...[
          _GroupHeader(
            label: l10n.groupAllGood(allGood.length),
            color: context.palette.success,
            expanded: _showAllGood,
            onTap: () => setState(() => _showAllGood = !_showAllGood),
          ),
          if (_showAllGood) rows(allGood),
          const SizedBox(height: 10),
        ],
        if (unknown.isNotEmpty) ...[
          _GroupHeader(
            label: l10n.groupUnknown(unknown.length),
            expanded: _showUnknown,
            onTap: () => setState(() => _showUnknown = !_showUnknown),
          ),
          if (_showUnknown) rows(unknown),
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
                final totalCost = totalSpend(logs);
                if (totalCost <= 0) return const SizedBox.shrink();
                return Text(
                  context.l10n.total(groupThousands(totalCost)),
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
            final visits = groupVisits(logs);
            if (visits.isEmpty) {
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
            final shown = visits.take(_historyShown).toList();
            return Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  VisitTile(visit: shown[i], imperial: imperial),
                ],
                if (visits.length > shown.length)
                  TextButton(
                    onPressed: () => setState(() => _historyShown += 10),
                    child: Text(context.l10n
                        .showMoreVisits(visits.length - shown.length)),
                  ),
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
                style: TextStyle(
                    fontSize: 11, color: context.palette.textSecondary)),
            Icon(Icons.arrow_drop_down,
                size: 16, color: context.palette.textSecondary),
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

class _GroupHeader extends StatelessWidget {
  final String label;
  final Color? color;
  final bool? expanded;
  final VoidCallback? onTap;
  const _GroupHeader(
      {required this.label, this.color, this.expanded, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(
          children: [
            EditorialLabel(label, color: color),
            const Spacer(),
            if (expanded != null)
              Icon(expanded! ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: context.palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Shown until the bike has been through setup: one question (when was the
/// oil last changed?) turns every guessed due date into a real one.
class _SetupCard extends StatelessWidget {
  final BikeEntity bike;
  const _SetupCard({required this.bike});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EditorialCard(
      key: const Key('maintenanceSetupCard'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      borderColor: context.palette.primary,
      onTap: () => context
          .push('/home/maintenance/setup?bikeId=${bike.id}&firstTime=true'),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high, color: context.palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.setupCardTitle,
                    style: display(context, 16, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(l10n.setupCardBody,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}
