import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../../domain/entities/service_visit.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/forecast_strip.dart';
import '../widgets/maintenance_check_row.dart';
import '../widgets/maintenance_format.dart';
import '../widgets/maintenance_log_tile.dart';
import '../widgets/maintenance_settings_section.dart' show exportServiceRecord;
import '../widgets/money_card.dart';
import '../widgets/odometer_sync_sheet.dart';
import '../widgets/paperwork_card.dart';
import '../widgets/quick_service_sheet.dart';
import '../widgets/up_next_card.dart';

/// Reorganized Maintenance Cockpit:
/// - 5-Second Cockpit header with Bike Health badge (All Systems Go vs Action Needed)
///   and Up-Next hero card ([⚡ Quick Log] and [⏳ Snooze]).
/// - Sticky 3-Pillar Segmented Navigation:
///     * Pillar 1: Service & Health (ForecastStrip, _SetupCard for BD bikes,
///       manual odo sync banner, grouped check rows, CheckDetailsSheet, FAB).
///     * Pillar 2: Records & Costs (Running cost rate ৳/km, 12m spend,
///       monthly spend bar chart, fuel economy tile, service visit history).
///     * Pillar 3: Docs & Safety (6-tile T-CLOCS precheck grid,
///       BRTA legal paperwork vault with 30-day expiry badges).
/// - Consolidated AppBar Action Menu (⋮) with PDF Export, manual odometer sync,
///   interval calibration, custom checks, and unit toggle.
class MaintenanceScreen extends ConsumerStatefulWidget {
  final String? bikeId;

  /// Injected in tests to move the date past midnight.
  final DateTime Function() clock;
  const MaintenanceScreen({super.key, this.bikeId, this.clock = DateTime.now});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen>
    with WidgetsBindingObserver {
  String? _selectedBikeId;
  int _selectedPillar =
      0; // 0: Service & Health, 1: Records & Costs, 2: Docs & Safety
  bool _showAllGood = false;
  bool _showUnknown = false;
  int _historyShown = 5;
  Timer? _midnightTimer;

  // Local state for interactive 6-tile T-CLOCS pre-ride inspection grid
  final Set<PrecheckItem> _precheckDefects = {};
  bool _precheckLogging = false;

  @override
  void initState() {
    super.initState();
    _selectedBikeId = widget.bikeId;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDay());
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncDay();
  }

  void _syncDay() {
    if (!mounted) return;
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final day = ref.read(maintenanceTodayProvider.notifier);
    if (day.state != today) day.state = today;
    _midnightTimer?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), _syncDay);
  }

  @override
  void didUpdateWidget(MaintenanceScreen old) {
    super.didUpdateWidget(old);
    if (widget.bikeId != null && widget.bikeId != old.bikeId) {
      _selectedBikeId = widget.bikeId;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(maintenanceTodayProvider); // rebuild day counts at midnight
    final bikes = ref.watch(garageProvider).valueOrNull ?? [];
    final activeBike = _selectedBikeId != null
        ? bikes.where((b) => b.id == _selectedBikeId).firstOrNull
        : (widget.bikeId != null
            ? bikes.where((b) => b.id == widget.bikeId).firstOrNull
            : ref.watch(activeBikeProvider));

    if (activeBike == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.background,
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => context.pop(),
                )
              : null,
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.two_wheeler,
                    size: 56, color: context.palette.textTertiary),
                const SizedBox(height: 16),
                Text(context.l10n.noActiveBike,
                    style: AppTypography.display(context, 20)),
                const SizedBox(height: 8),
                Text(
                  context.l10n.addMotorcycleGarageTrack,
                  style: TextStyle(
                      color: context.palette.textSecondary, fontSize: 13),
                ),
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
    final needsSetup = profile?.onboardedAt == null && !customized;

    final forecasts = ref.watch(maintenanceForecastProvider(activeBike.id));
    final issues =
        ref.watch(precheckIssuesProvider(activeBike.id)).valueOrNull ??
            const [];

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: _buildAppBar(bikes, activeBike, imperial),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('logVisitFab'),
        onPressed: () => QuickServiceSheet.show(context, bike: activeBike),
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text(
          context.l10n.logVisitTitle,
          style:
              const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: context.palette.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMd,
            8,
            AppDimensions.paddingMd,
            96,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 5-Second Cockpit: Odometer, Tactical Health Badge & Hero Card
              _buildCockpitHeader(activeBike, imperial, forecasts, issues),
              const SizedBox(height: 14),

              // Sticky 3-Pillar Segmented Navigation Pills
              _buildSegmentedPills(),
              const SizedBox(height: 14),

              // Active Pillar Content
              if (_selectedPillar == 0)
                _buildPillar1ServiceHealth(activeBike, imperial, needsSetup)
              else if (_selectedPillar == 1)
                _buildPillar2RecordsCosts(activeBike, imperial)
              else
                _buildPillar3DocsSafety(activeBike),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      List<BikeEntity> bikes, BikeEntity activeBike, bool imperial) {
    final palette = context.palette;
    return AppBar(
      backgroundColor: palette.background,
      elevation: 0,
      centerTitle: false,
      leading: context.canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => context.pop(),
            )
          : null,
      title: Text(
        context.l10n.maintenance.toUpperCase(),
        style: AppTypography.display(context, 16, weight: FontWeight.w700),
      ),
      actions: [
        if (bikes.length > 1) _buildBikeChip(bikes, activeBike),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: palette.textSecondary),
          tooltip: context.l10n.maintSettingsTitle,
          color: palette.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.shape.radiusMd),
            side: BorderSide(color: palette.border),
          ),
          onSelected: (action) {
            switch (action) {
              case 'export_pdf':
                exportServiceRecord(context, ref, activeBike);
                break;
              case 'calibrate_intervals':
                context.push('/home/maintenance/setup?bikeId=${activeBike.id}');
                break;
              case 'custom_checks':
                context.push(
                    '/home/maintenance/configure?bikeId=${activeBike.id}');
                break;
              case 'sync_odometer':
                OdometerSyncSheet.show(context, activeBike);
                break;
              case 'toggle_units':
                ref.read(maintenanceImperialProvider.notifier).set(!imperial);
                break;
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'export_pdf',
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(context.l10n.exportServiceRecord,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'calibrate_intervals',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(context.l10n.maintScheduleTitle,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'custom_checks',
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 10),
                  Text(context.l10n.maintCustomizeChecks,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sync_odometer',
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 18),
                  const SizedBox(width: 10),
                  Text(context.l10n.maintSyncOdometer,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_units',
              child: Row(
                children: [
                  const Icon(Icons.straighten, size: 18),
                  const SizedBox(width: 10),
                  Text(imperial ? 'Units: Imperial (mi)' : 'Units: Metric (km)',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBikeChip(List<BikeEntity> bikes, BikeEntity activeBike) {
    final palette = context.palette;
    return PopupMenuButton<String>(
      tooltip: context.l10n.switchBike,
      color: palette.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        side: BorderSide(color: palette.border),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeBike.colorValue != null
                    ? Color(activeBike.colorValue!)
                    : palette.primary,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                activeBike.displayName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: palette.textSecondary),
          ],
        ),
      ),
      onSelected: (id) => setState(() => _selectedBikeId = id),
      itemBuilder: (ctx) => bikes
          .map((b) => PopupMenuItem<String>(
                value: b.id,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: b.colorValue != null
                            ? Color(b.colorValue!)
                            : palette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: b.id == activeBike.id
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  /// 5-Second Cockpit: Odometer reading in IBM Plex Mono + Tactical Bike Health Badge
  Widget _buildCockpitHeader(
    BikeEntity activeBike,
    bool imperial,
    List<CheckForecast> forecasts,
    List<PrecheckIssue> issues,
  ) {
    final palette = context.palette;
    final attentionCount =
        forecasts.where((f) => f.needsAttention).length + issues.length;
    final allGood = attentionCount == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  groupThousands(activeBike.currentOdometerKm),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  imperial ? 'MI TELEMETRY' : 'KM TELEMETRY',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setState(() => _selectedPillar = 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: palette.surfaceVariant,
                    duration: const Duration(seconds: 3),
                    content: Text(
                      allGood
                          ? 'Tactile Diagnostics: All systems nominal. All tracked checks healthy.'
                          : 'Tactile Diagnostics: $attentionCount check(s) need attention.',
                      style: TextStyle(color: palette.textPrimary),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(context.shape.radiusFull),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allGood
                      ? palette.success.withValues(alpha: 0.15)
                      : palette.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(context.shape.radiusFull),
                  border: Border.all(
                    color: allGood
                        ? palette.success.withValues(alpha: 0.4)
                        : palette.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: allGood ? palette.success : palette.danger,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      allGood
                          ? 'ALL SYSTEMS GO'
                          : (attentionCount == 1
                              ? '1 ACTION NEEDED'
                              : '$attentionCount ACTIONS NEEDED'),
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: allGood ? palette.success : palette.danger,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        UpNextCard(bikeId: activeBike.id, imperial: imperial),
      ],
    );
  }

  /// Sticky 3-Pillar Segmented Navigation Pills (Carbon Mono Dark)
  Widget _buildSegmentedPills() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: context.palette.background,
      child: Row(
        children: [
          Expanded(
            child: _Pill(
              icon: '🩺',
              label: 'SERVICE & HEALTH',
              active: _selectedPillar == 0,
              onTap: () => setState(() => _selectedPillar = 0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _Pill(
              icon: '📊',
              label: 'RECORDS & COSTS',
              active: _selectedPillar == 1,
              onTap: () => setState(() => _selectedPillar = 1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _Pill(
              icon: '🛡️',
              label: 'DOCS & SAFETY',
              active: _selectedPillar == 2,
              onTap: () => setState(() => _selectedPillar = 2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pillar 1: Service & Health ──────────────────────────────────────────

  Widget _buildPillar1ServiceHealth(
      BikeEntity activeBike, bool imperial, bool needsSetup) {
    final palette = context.palette;
    final shape = context.shape;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OEM Schedule Setup Card (For Bangladesh bikes)
        if (needsSetup) ...[
          _SetupCard(bike: activeBike),
          const SizedBox(height: 14),
        ],

        // Manual Odometer Calibration Banner
        EditorialCard(
          key: const Key('maintenanceManualOdometer'),
          radius: shape.radiusMd,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          onTap: () => OdometerSyncSheet.show(context, activeBike),
          child: Row(
            children: [
              Icon(Icons.speed, color: palette.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.maintSyncOdometer,
                      style: AppTypography.display(context, 13.5,
                          weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Reading: ${distLabelLong(activeBike.currentOdometerKm, imperial)} · Tap to sync',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'SYNC ›',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 60-Day Visual Wear Forecast Timeline Strip
        ForecastStrip(
          bikeId: activeBike.id,
          forecasts: ref.watch(maintenanceForecastProvider(activeBike.id)),
        ),
        const SizedBox(height: 16),

        // Grouped Check Rows (Attention, Coming Up, All Good, Unknown)
        _buildChecks(activeBike, imperial),
      ],
    );
  }

  Widget _buildChecks(BikeEntity bike, bool imperial) {
    final l10n = context.l10n;
    final forecasts = ref.watch(maintenanceForecastProvider(bike.id));
    final issues =
        ref.watch(precheckIssuesProvider(bike.id)).valueOrNull ?? const [];
    final now = widget.clock();

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
          child: Text(
            l10n.noChecksTrackedYet,
            style: TextStyle(color: context.palette.textTertiary, fontSize: 13),
          ),
        ),
      );
    }

    Widget rows(List<CheckForecast> list) => Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              MaintenanceCheckRow(
                forecast: list[i],
                imperial: imperial,
                bikeId: bike.id,
              ),
            ],
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attention.isNotEmpty || issues.isNotEmpty) ...[
          _GroupHeader(
            label: l10n.groupNeedsAttention(attention.length + issues.length),
            color: context.palette.danger,
          ),
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

  // ── Pillar 2: Records & Costs ───────────────────────────────────────────

  Widget _buildPillar2RecordsCosts(BikeEntity activeBike, bool imperial) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Operating Cost Hero Card with ৳/km and Monthly Bar Chart
        MoneyCard(bikeId: activeBike.id, imperial: imperial),
        const SizedBox(height: 14),

        // Fuel Economy Hub Tile
        EditorialCard(
          key: const Key('maintenanceFuelLink'),
          radius: context.shape.radiusLg,
          padding: const EdgeInsets.all(14),
          onTap: () =>
              context.push('/home/maintenance/fuel?bikeId=${activeBike.id}'),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(context.shape.radiusSm),
                  border: Border.all(color: context.palette.border),
                ),
                child: Icon(Icons.local_gas_station_outlined,
                    color: context.palette.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.fuelLogTitle,
                        style: AppTypography.display(context, 14.5,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Track fuel consumption & cost efficiency',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: context.palette.textSecondary)),
                  ],
                ),
              ),
              Text(
                'OPEN LOG ›',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.palette.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Service Visit History Timeline
        _buildHistory(activeBike, imperial),
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
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.palette.primary,
                  ),
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
                      Text(
                        context.l10n.noServiceRecordsLogged,
                        style: TextStyle(
                            color: context.palette.textSecondary, fontSize: 13),
                      ),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () => setState(() => _historyShown += 10),
                      child: Text(
                        context.l10n
                            .showMoreVisits(visits.length - shown.length),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.palette.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Pillar 3: Docs & Safety ─────────────────────────────────────────────

  Widget _buildPillar3DocsSafety(BikeEntity activeBike) {
    final palette = context.palette;
    final shape = context.shape;
    final allPassed = _precheckDefects.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // T-CLOCS 30-Second Pre-Ride Inspection Card
        EditorialCard(
          radius: shape.radiusLg,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'T-CLOCS 30-SECOND PRE-RIDE CHECK',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: allPassed
                          ? palette.success.withValues(alpha: 0.15)
                          : palette.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(shape.radiusSm),
                      border: Border.all(
                        color: allPassed
                            ? palette.success.withValues(alpha: 0.3)
                            : palette.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      allPassed
                          ? 'ALL 6 PASSED'
                          : '${_precheckDefects.length} DEFECT DETECTED',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: allPassed ? palette.success : palette.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap any component to flag defects before departure:',
                style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
              ),
              const SizedBox(height: 12),

              // 6-Tile Tactile Grid (Tires, Controls, Lights, Oil, Chain, Stands)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
                children: [
                  for (final item in PrecheckItem.values)
                    _TclocsGridTile(
                      item: item,
                      defect: _precheckDefects.contains(item),
                      onTap: () {
                        setState(() {
                          if (_precheckDefects.contains(item)) {
                            _precheckDefects.remove(item);
                          } else {
                            _precheckDefects.add(item);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Log Pre-Ride Inspection Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('precheckSave'),
                  onPressed: _precheckLogging
                      ? null
                      : () async {
                          setState(() => _precheckLogging = true);
                          await ref
                              .read(precheckIssuesProvider(activeBike.id)
                                  .notifier)
                              .record(_precheckDefects.toList());
                          if (!mounted) return;
                          setState(() => _precheckLogging = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: palette.surfaceVariant,
                              content: Text(
                                allPassed
                                    ? '✓ T-CLOCS pre-ride inspection stamped nominal'
                                    : '⚠️ Defect flagged and tracked in Service & Health',
                                style: TextStyle(color: palette.textPrimary),
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        allPassed ? palette.primary : palette.danger,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(shape.radiusMd),
                    ),
                  ),
                  child: Text(
                    allPassed
                        ? '✓ LOG PRE-RIDE INSPECTION'
                        : '⚠️ LOG ${_precheckDefects.length} DEFECT(S)',
                    style: AppTypography.display(
                      context,
                      12,
                      color: Colors.black,
                      weight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // BRTA Legal Paperwork Vault with 30-Day Expiry Badges
        PaperworkCard(bikeId: activeBike.id),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = context.shape;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(shape.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: active ? palette.surfaceVariant : palette.surface,
          borderRadius: BorderRadius.circular(shape.radiusFull),
          border: Border.all(
            color: active ? palette.primary : palette.border,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  context,
                  9.5,
                  color: active ? palette.primary : palette.textSecondary,
                  weight: active ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TclocsGridTile extends StatelessWidget {
  final PrecheckItem item;
  final bool defect;
  final VoidCallback onTap;

  const _TclocsGridTile({
    required this.item,
    required this.defect,
    required this.onTap,
  });

  IconData get _icon => switch (item) {
        PrecheckItem.tires => Icons.tire_repair,
        PrecheckItem.controls => Icons.tune,
        PrecheckItem.lights => Icons.lightbulb_outline,
        PrecheckItem.oil => Icons.opacity,
        PrecheckItem.chain => Icons.link,
        PrecheckItem.stands => Icons.vertical_align_bottom,
      };

  String get _subtitle => switch (item) {
        PrecheckItem.tires => '32F / 36R PSI',
        PrecheckItem.controls => 'Clutch / throttle',
        PrecheckItem.lights => 'Brake & signals',
        PrecheckItem.oil => 'Sight glass level',
        PrecheckItem.chain => '25mm slack',
        PrecheckItem.stands => 'Spring cutoff',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = context.shape;
    final color = defect ? palette.danger : palette.success;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(shape.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: defect
              ? palette.danger.withValues(alpha: 0.12)
              : palette.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(shape.radiusMd),
          border: Border.all(
            color: defect
                ? palette.danger
                : palette.success.withValues(alpha: 0.4),
            width: defect ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name[0].toUpperCase() + item.name.substring(1),
                    style: AppTypography.display(context, 12,
                        weight: FontWeight.w700),
                  ),
                  Text(
                    defect ? 'DEFECT' : _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: defect ? palette.danger : palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                    style:
                        AppTypography.display(context, 16, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(
                  l10n.setupCardBody,
                  style: TextStyle(
                      fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}
