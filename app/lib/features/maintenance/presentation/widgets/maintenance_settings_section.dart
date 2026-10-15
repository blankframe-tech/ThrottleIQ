import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../data/services/maintenance_alerts.dart';
import '../../data/services/service_record_pdf.dart';
import '../../domain/calculators/fuel_units.dart';
import '../../domain/entities/service_visit.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'forecast_text.dart';
import 'maintenance_format.dart';
import 'odometer_sync_sheet.dart';
import 'reset_maintenance_log_sheet.dart';
import 'running_costs_sheet.dart';

/// Everything that configures the maintenance page rather than being part
/// of its day-to-day content, gathered in one card at the end of the page:
/// which checks to track, odometer sync, bulk reset, distance units, and
/// running costs (fuel price, mileage, per-service costs).
class MaintenanceSettingsSection extends ConsumerWidget {
  final BikeEntity bike;
  const MaintenanceSettingsSection({super.key, required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final imperial = ref.watch(maintenanceImperialProvider);
    final profile = ref.watch(maintenanceProfileProvider(bike.id)).valueOrNull;
    final alertsOn = ref.watch(maintenanceAlertsEnabledProvider);
    final perKm = ref
        .watch(rideCostProvider((bikeId: bike.id, distanceKm: 1)))
        ?.costPerKm;
    final String costSubtitle;
    if (perKm == null || perKm <= 0) {
      costSubtitle = l10n.maintRunningCostsEmpty;
    } else {
      final rate = imperial ? FuelUnits.costPerKmToPerMile(perKm) : perKm;
      costSubtitle =
          l10n.maintCostPerUnit(formatTakaRate(rate), imperial ? 'mi' : 'km');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialLabel(l10n.maintSettingsTitle),
        const SizedBox(height: 10),
        EditorialCard(
          radius: context.shape.radiusLg,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.payments_outlined,
                title: l10n.maintRunningCosts,
                subtitle: costSubtitle,
                onTap: () => RunningCostsSheet.show(context, bike.id),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.event_note,
                title: l10n.maintScheduleTitle,
                subtitle: profile == null
                    ? l10n.maintScheduleNotSet
                    : '${profile.template.name} · ${ridingProfileLabel(profile.ridingProfile, l10n)}',
                onTap: () =>
                    context.push('/home/maintenance/setup?bikeId=${bike.id}'),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.auto_graph,
                title: l10n.maintAdaptTitle,
                subtitle: l10n.maintAdaptSubtitle,
                trailing: Switch.adaptive(
                  value: profile?.adaptIntervals ?? true,
                  onChanged: (v) => ref
                      .read(maintenanceProfileProvider(bike.id).notifier)
                      .setAdaptIntervals(v),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: l10n.maintRemindersTitle,
                subtitle: l10n.maintRemindersSubtitle,
                trailing: Switch.adaptive(
                  value: alertsOn,
                  onChanged: (v) =>
                      ref.read(maintenanceAlertsEnabledProvider.notifier).set(v),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.tune,
                title: l10n.maintCustomizeChecks,
                subtitle: l10n.maintCustomizeChecksSubtitle,
                onTap: () => context
                    .push('/home/maintenance/configure?bikeId=${bike.id}'),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.speed,
                title: l10n.maintSyncOdometer,
                subtitle: l10n.maintSyncOdometerSubtitle,
                onTap: () => OdometerSyncSheet.show(context, bike),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.restart_alt,
                title: l10n.resetServiceLog,
                subtitle: l10n.maintResetLogSubtitle,
                onTap: () => ResetMaintenanceLogSheet.show(context, bike),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.picture_as_pdf_outlined,
                title: l10n.exportServiceRecord,
                subtitle: l10n.exportServiceRecordSubtitle,
                onTap: () => exportServiceRecord(context, ref, bike),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.straighten,
                title: l10n.maintDistanceUnits,
                trailing: MaintenanceUnitToggle(
                  imperial: imperial,
                  onChanged: (v) =>
                      ref.read(maintenanceImperialProvider.notifier).set(v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 48, color: context.palette.border.withValues(alpha: 0.6));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.palette.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 11,
                            color: context.palette.textTertiary,
                            height: 1.25)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(Icons.chevron_right,
                    size: 18, color: context.palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// km / mi segmented toggle.
class MaintenanceUnitToggle extends StatelessWidget {
  final bool imperial;
  final ValueChanged<bool> onChanged;
  const MaintenanceUnitToggle({super.key, required this.imperial, required this.onChanged});

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
    // issues §101.R9: announce the segment as a button and which unit is
    // active. excludeSemantics drops the bare text node, so the tap is
    // re-exposed here.
    return Semantics(
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
      ),
    );
  }
}


/// The "Maintenance reminders" switch, mirrored from MaintenanceAlerts'
/// stored preference.
class MaintenanceAlertsEnabledNotifier extends StateNotifier<bool> {
  MaintenanceAlertsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await MaintenanceAlerts.isEnabled();
      if (mounted) state = v;
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'Maintenance alerts: load setting failed');
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      await MaintenanceAlerts.instance.setEnabled(on);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'Maintenance alerts: save setting failed');
    }
  }
}

final maintenanceAlertsEnabledProvider =
    StateNotifierProvider<MaintenanceAlertsEnabledNotifier, bool>(
        (ref) => MaintenanceAlertsEnabledNotifier());

/// Builds the service-record PDF for [bike] and opens the system print /
/// share sheet.
Future<void> exportServiceRecord(
    BuildContext context, WidgetRef ref, BikeEntity bike) async {
  final l10n = context.l10n;
  final imperial = ref.read(maintenanceImperialProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final logs = await ref.read(maintenanceProvider(bike.id).future);
    final visits = groupVisits(logs);
    if (visits.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportNothingYet)));
      return;
    }
    if (!context.mounted) return;
    final total = totalSpend(logs);
    String fmtDate(DateTime d) => longDate(context, d);
    final font = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansBengali-Variable.ttf'));
    final bytes = await buildServiceRecordPdf(
      visits: visits,
      baseFont: font,
      s: ServiceRecordStrings(
        title: l10n.serviceRecordTitle,
        bikeLine:
            '${bike.displayName} · ${distLabelLong(bike.currentOdometerKm, imperial)}',
        generatedOn: l10n.serviceRecordGenerated(fmtDate(DateTime.now())),
        colDate: l10n.serviceRecordColDate,
        colOdometer: l10n.serviceRecordColOdometer,
        colWork: l10n.serviceRecordColWork,
        colShop: l10n.serviceRecordColShop,
        colCost: l10n.serviceRecordColCost,
        totalLine: l10n.serviceRecordTotal(visits.length, groupThousands(total)),
        footer: l10n.serviceRecordFooter,
        formatDate: fmtDate,
        formatKm: (km) => distLabelLong(km, imperial),
        workOf: (v) => [
          if (v.freeServiceNumber != null) l10n.freeServiceN(v.freeServiceNumber!),
          ...v.items.map((i) => [
                i.localizedDisplayLabel(l10n),
                if ((i.partBrand ?? '').isNotEmpty) i.partBrand,
                if ((i.partGrade ?? '').isNotEmpty) i.partGrade,
              ].whereType<String>().join(' ')),
        ].join(', '),
        shopOf: (v) => [
          if ((v.shopName ?? '').isNotEmpty) v.shopName!,
          if (v.shopKind != null) shopKindLabel(v.shopKind!, l10n),
        ].join(' · '),
      ),
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'service-record-${bike.model.replaceAll(' ', '-')}.pdf',
    );
  } catch (e, st) {
    reportNonFatal(e, st, reason: 'Service record: export failed');
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
  }
}
