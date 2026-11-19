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
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/maintenance_check_row.dart';
import '../widgets/maintenance_format.dart';
import '../widgets/maintenance_settings_section.dart' show exportServiceRecord;
import '../widgets/odometer_sync_sheet.dart';
import '../widgets/precheck_sheet.dart';
import '../widgets/quick_service_sheet.dart';
import '../widgets/up_next_card.dart';

/// Maintenance, in one glance: what's next (with "Done it"), the checks that
/// need attention, and everything else collapsed. Costs, fuel, paperwork and
/// service history live one tap away on [MaintenanceRecordsScreen].
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
  static const _comingUpDays = 60;
  String? _selectedBikeId;
  bool _showAllGood = false;
  bool _showUnknown = false;
  Timer? _midnightTimer;

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
            96, // clears the FAB
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOdometer(activeBike, imperial),
              const SizedBox(height: 12),
              if (needsSetup) ...[
                _SetupCard(bike: activeBike),
                const SizedBox(height: 12),
              ],
              UpNextCard(bikeId: activeBike.id, imperial: imperial),
              const SizedBox(height: 18),
              _buildChecks(activeBike, imperial),
              const SizedBox(height: 18),
              PrecheckCard(bikeId: activeBike.id),
              const SizedBox(height: 10),
              _buildRecordsLink(activeBike),
            ],
          ),
        ),
      ),
    );
  }

  /// One tap to correct the reading; it drives every due date below.
  Widget _buildOdometer(BikeEntity bike, bool imperial) {
    final palette = context.palette;
    return InkWell(
      key: const Key('maintenanceManualOdometer'),
      onTap: () => OdometerSyncSheet.show(context, bike),
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.speed, size: 18, color: palette.textSecondary),
            const SizedBox(width: 8),
            Text(
              distLabelLong(bike.currentOdometerKm, imperial),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(Icons.edit_outlined, size: 16, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsLink(BikeEntity bike) {
    final palette = context.palette;
    return EditorialCard(
      key: const Key('maintenanceRecordsLink'),
      radius: context.shape.radiusLg,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/home/maintenance/records?bikeId=${bike.id}'),
      child: Row(
        children: [
          Icon(Icons.history, color: palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.l10n.maintRecordsTitle,
                style: AppTypography.display(context, 15, letterSpacing: 0)),
          ),
          Icon(Icons.chevron_right, color: palette.textTertiary),
        ],
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
              value: 'toggle_units',
              child: Row(
                children: [
                  const Icon(Icons.straighten, size: 18),
                  const SizedBox(width: 10),
                  Text(
                      '${context.l10n.maintDistanceUnits}: ${imperial ? 'mi' : 'km'}',
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
            (f.daysUntilDue(now) ?? 9999) <= _comingUpDays)
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
