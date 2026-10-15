import '../../../../core/utils/parse_localized_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/calculators/fuel_units.dart';
import '../../domain/calculators/ride_cost_calculator.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'edit_maintenance_check_sheet.dart';
import 'maintenance_format.dart';

/// Where the rider tells the app what riding this bike costs: fuel price and
/// mileage, plus a typical price for each tracked check. Feeds the "Ride
/// cost" card on the ride summary. Opened from Maintenance settings, and
/// from the ride summary's empty-state hint.
class RunningCostsSheet extends ConsumerStatefulWidget {
  final String bikeId;
  const RunningCostsSheet({super.key, required this.bikeId});

  static Future<void> show(BuildContext context, String bikeId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RunningCostsSheet(bikeId: bikeId),
    );
  }

  @override
  ConsumerState<RunningCostsSheet> createState() => _RunningCostsSheetState();
}

class _RunningCostsSheetState extends ConsumerState<RunningCostsSheet> {
  final _priceCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _mileageCtrl.dispose();
    super.dispose();
  }

  String _fmt(double? v) {
    if (v == null || v <= 0) return '';
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _seed(BikeRunningCostEntity running, bool imperial) {
    if (_seeded) return;
    _seeded = true;
    final price = running.fuelPricePerLitre;
    final kmpl = running.kmPerLitre;
    _priceCtrl.text = _fmt(price == null
        ? null
        : (imperial ? FuelUnits.pricePerLitreToPerGallon(price) : price));
    _mileageCtrl.text = _fmt(kmpl == null
        ? null
        : (imperial ? FuelUnits.kmPerLitreToMpg(kmpl) : kmpl));
  }

  Future<void> _saveFuel(bool imperial) async {
    final price = parseLocalizedNumber(_priceCtrl.text.trim());
    final mileage = parseLocalizedNumber(_mileageCtrl.text.trim());
    setState(() => _saving = true);
    await ref.read(bikeRunningCostProvider(widget.bikeId).notifier).save(
          fuelPricePerLitre: price == null
              ? null
              : (imperial ? FuelUnits.pricePerGallonToPerLitre(price) : price),
          kmPerLitre: mileage == null
              ? null
              : (imperial ? FuelUnits.mpgToKmPerLitre(mileage) : mileage),
        );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final imperial = ref.watch(maintenanceImperialProvider);
    final running = ref.watch(bikeRunningCostProvider(widget.bikeId)).valueOrNull;
    if (running != null) _seed(running, imperial);
    final configs =
        ref.watch(maintenanceConfigProvider(widget.bikeId)).valueOrNull ?? [];
    final logs = ref.watch(maintenanceProvider(widget.bikeId)).valueOrNull ?? [];
    final breakdown =
        ref.watch(rideCostProvider((bikeId: widget.bikeId, distanceKm: 1)));
    final tracked = configs
        .where((c) => c.isEnabled && c.serviceType != ServiceType.fuel)
        .toList();
    final unit = imperial ? 'mi' : 'km';
    double rate(double perKm) =>
        imperial ? FuelUnits.costPerKmToPerMile(perKm) : perKm;

    final numberFormatter = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ];

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(context.shape.radiusXl)),
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingMd, 14,
          AppDimensions.paddingMd,
          MediaQuery.of(context).viewInsets.bottom + AppDimensions.paddingMd),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.maintRunningCosts, style: display(context, 20)),
            const SizedBox(height: 4),
            Text(
              breakdown == null || breakdown.isEmpty
                  ? l10n.maintRunningCostsEmpty
                  : l10n.maintCostPerUnit(
                      formatTakaRate(rate(breakdown.costPerKm)), unit),
              style:
                  TextStyle(fontSize: 12, color: context.palette.textSecondary),
            ),
            const SizedBox(height: 18),

            // ── Fuel ───────────────────────────────────────────────────
            EditorialLabel(ServiceType.fuel.localizedLabel(l10n)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fuelPriceField'),
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numberFormatter,
                    onChanged: (_) => setState(() => _saved = false),
                    decoration: InputDecoration(
                      labelText: imperial
                          ? l10n.maintFuelPricePerGallon
                          : l10n.maintFuelPricePerLitre,
                      prefixText: '৳ ',
                      filled: true,
                      fillColor: context.palette.surfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('mileageField'),
                    controller: _mileageCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numberFormatter,
                    onChanged: (_) => setState(() => _saved = false),
                    decoration: InputDecoration(
                      labelText: l10n.maintAverageMileage,
                      suffixText: imperial ? 'mpg' : 'km/l',
                      filled: true,
                      fillColor: context.palette.surfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _saveFuel(imperial),
                icon: Icon(_saved ? Icons.check : Icons.save_outlined, size: 16),
                label: Text(l10n.safeQrSaveAction),
              ),
            ),
            const SizedBox(height: 14),

            // ── Per-service costs ──────────────────────────────────────
            EditorialLabel(l10n.maintServiceCosts),
            const SizedBox(height: 4),
            Text(l10n.maintServiceCostsHint,
                style: TextStyle(
                    fontSize: 11, color: context.palette.textTertiary)),
            const SizedBox(height: 8),
            if (tracked.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.noChecksTrackedYet,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textTertiary)),
              )
            else
              for (final c in tracked)
                _ServiceCostRow(
                  config: c,
                  priced: RideCostCalculator.itemCostPerKm(
                    intervalKm: c.intervalKm,
                    typicalCost: c.typicalCost,
                    logs: logs.where((l) => l.serviceType == c.serviceType),
                  ),
                  averageLogged: RideCostCalculator.averageLoggedCost(
                      logs.where((l) => l.serviceType == c.serviceType)),
                  unit: unit,
                  rate: rate,
                  imperial: imperial,
                ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCostRow extends StatelessWidget {
  final MaintenanceConfigEntity config;
  final ({double costPerKm, CostSource source})? priced;
  final double? averageLogged;
  final String unit;
  final double Function(double) rate;
  final bool imperial;

  const _ServiceCostRow({
    required this.config,
    required this.priced,
    required this.averageLogged,
    required this.unit,
    required this.rate,
    required this.imperial,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String source;
    if (priced?.source == CostSource.history && averageLogged != null) {
      source = l10n.maintCostFromHistory(formatTaka(averageLogged!));
    } else if (priced?.source == CostSource.typical &&
        config.typicalCost != null) {
      source = l10n.maintCostFromTypical(formatTaka(config.typicalCost!));
    } else {
      source = l10n.maintCostNotSet;
    }
    return InkWell(
      onTap: () => EditMaintenanceCheckSheet.show(context, config: config),
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Icon(iconForServiceType(config.serviceType),
                size: 18, color: context.palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(config.serviceType.localizedLabel(l10n),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary)),
                  Text(
                    '$source · ${l10n.intervalEvery(distLabel(config.intervalKm, imperial))}',
                    style: TextStyle(
                        fontSize: 11, color: context.palette.textTertiary),
                  ),
                ],
              ),
            ),
            Text(
              priced == null
                  ? '—'
                  : '৳${formatTakaRate(rate(priced!.costPerKm))}/$unit',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: priced == null
                      ? context.palette.textTertiary
                      : context.palette.textPrimary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                size: 14, color: context.palette.textTertiary),
          ],
        ),
      ),
    );
  }
}
