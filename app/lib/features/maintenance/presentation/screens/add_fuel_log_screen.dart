import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../core/utils/parse_localized_number.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/fuel_economy.dart';
import '../../domain/entities/fuel_log.dart';
import '../providers/fuel_provider.dart';
import '../widgets/forecast_text.dart';

/// Add or edit one fuel fill-up. The odometer is prefilled from the bike
/// and can be set back by "km ago" for a fill the rider forgot to log; the
/// rider types any two of litres, total paid and price per litre (prefilled
/// from the last fill) and the third is worked out.
class AddFuelLogScreen extends ConsumerStatefulWidget {
  final String bikeId;

  /// The fill-up to edit; null to add a new one.
  final String? logId;

  /// Injectable clock for tests.
  final DateTime? now;

  const AddFuelLogScreen({
    super.key,
    required this.bikeId,
    this.logId,
    this.now,
  });

  @override
  ConsumerState<AddFuelLogScreen> createState() => _AddFuelLogScreenState();
}

/// The three linked number fields; the rider types two, the third is derived.
enum _Field { liters, total, price }

class _AddFuelLogScreenState extends ConsumerState<AddFuelLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _kmAgoCtrl = TextEditingController();
  late DateTime _filledAt = widget.now ?? DateTime.now();
  bool _fullTank = true;

  /// The fields the rider typed (or that were prefilled), oldest first, at
  /// most two. Whatever isn't here is derived.
  final _typed = <_Field>[];

  /// The prefilled odometer that "km ago" counts back from.
  double _baseOdo = 0;
  bool _loaded = false;
  bool _saving = false;

  bool get _editing => widget.logId != null;

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _litersCtrl.dispose();
    _totalCtrl.dispose();
    _priceCtrl.dispose();
    _stationCtrl.dispose();
    _noteCtrl.dispose();
    _kmAgoCtrl.dispose();
    super.dispose();
  }

  static String _num(double v, {int decimals = 2}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  void _prefill(List<FuelLogEntity> logs) {
    if (_loaded) return;
    final bike = ref
            .read(allBikesProvider)
            .valueOrNull
            ?.where((b) => b.id == widget.bikeId)
            .firstOrNull ??
        ref
            .read(garageProvider)
            .valueOrNull
            ?.where((b) => b.id == widget.bikeId)
            .firstOrNull;
    if (_editing) {
      final log = logs.where((l) => l.id == widget.logId).firstOrNull;
      if (log == null) return;
      _loaded = true;
      _filledAt = log.filledAt;
      _odometerCtrl.text = _num(log.odometerKm, decimals: 1);
      _litersCtrl.text = _num(log.liters);
      _totalCtrl.text = _num(log.totalCost);
      _priceCtrl.text = _num(log.pricePerLiter);
      _fullTank = log.fullTank;
      _stationCtrl.text = log.station ?? '';
      _noteCtrl.text = log.note ?? '';
      _typed.addAll([_Field.liters, _Field.total]);
      return;
    }
    if (bike == null) return;
    _loaded = true;
    // The bike's odometer, or the last fill-up's if that's further along.
    var odo = bike.currentOdometerKm;
    for (final l in logs) {
      if (l.odometerKm > odo) odo = l.odometerKm;
    }
    _baseOdo = odo;
    _odometerCtrl.text = odo.toStringAsFixed(0);
    // Most riders use the same pump at the same price.
    final last = logs.firstOrNull;
    if (last != null) {
      _priceCtrl.text = _num(last.pricePerLiter);
      _typed.add(_Field.price);
      _stationCtrl.text = last.station ?? '';
    }
  }

  TextEditingController _ctrl(_Field f) => switch (f) {
        _Field.liters => _litersCtrl,
        _Field.total => _totalCtrl,
        _Field.price => _priceCtrl,
      };

  /// The fill-up from the two typed fields, at full precision.
  ({double liters, double totalCost, double pricePerLiter})? _fill() {
    double? typed(_Field f) =>
        _typed.contains(f) ? parseLocalizedNumber(_ctrl(f).text) : null;
    return completeFuelFill(
        liters: typed(_Field.liters),
        totalCost: typed(_Field.total),
        pricePerLiter: typed(_Field.price));
  }

  /// Marks [f] as typed (or untyped when cleared) and rewrites the derived
  /// field from the other two.
  void _onTyped(_Field f, String v) {
    _typed.remove(f);
    if (v.trim().isNotEmpty) _typed.add(f);
    if (_typed.length > 2) _typed.removeAt(0);
    final fill = _typed.length == 2 ? _fill() : null;
    for (final d in _Field.values.where((x) => !_typed.contains(x))) {
      _ctrl(d).text = fill == null
          ? ''
          : _num(switch (d) {
              _Field.liters => fill.liters,
              _Field.total => fill.totalCost,
              _Field.price => fill.pricePerLiter,
            });
    }
  }

  /// "Filled N km ago": sets the odometer back from the prefilled reading.
  void _onKmAgo(String v) {
    final ago = parseLocalizedNumber(v, min: 0, max: _baseOdo);
    _odometerCtrl.text = (_baseOdo - (ago ?? 0)).toStringAsFixed(0);
  }

  String? _odometerError(String? v, List<FuelLogEntity> logs) {
    final l10n = context.l10n;
    if (v == null || v.trim().isEmpty) return l10n.requiredField;
    final n = parseLocalizedNumber(v, min: 0, max: 2000000);
    if (n == null) return l10n.invalidNumber;
    return switch (fillOdometerConflict(
        odometerKm: n,
        filledAt: _filledAt,
        others: logs,
        excludeId: widget.logId)) {
      FuelOdometerConflict.belowEarlierFill => l10n.fuelOdometerBelowEarlier,
      FuelOdometerConflict.aboveLaterFill => l10n.fuelOdometerAboveLater,
      null => null,
    };
  }

  String? _moneyError(String? v) {
    final l10n = context.l10n;
    final total = _totalCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    if (total.isEmpty && price.isEmpty) return l10n.fuelMoneyRequired;
    if (v == null || v.trim().isEmpty) return null;
    return parseLocalizedNumber(v, min: 0, max: 10000000) == null
        ? l10n.invalidNumber
        : null;
  }

  Future<void> _pickDate() async {
    final today = widget.now ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filledAt.isAfter(today) ? today : _filledAt,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() => _filledAt = DateTime(picked.year, picked.month, picked.day,
        _filledAt.hour, _filledAt.minute, _filledAt.second));
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final fill = _fill();
    if (fill == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(fuelLogsProvider(widget.bikeId).notifier).save(
            FuelLogDraft(
              filledAt: _filledAt,
              odometerKm: parseLocalizedNumber(_odometerCtrl.text)!,
              liters: fill.liters,
              totalCost: fill.totalCost,
              pricePerLiter: fill.pricePerLiter,
              fullTank: _fullTank,
              station: _stationCtrl.text,
              note: _noteCtrl.text,
            ),
            id: widget.logId,
          );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'AddFuelLog: save failed');
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.fuelSaveFailed)));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text(_editing ? l10n.fuelUpdated : l10n.fuelSaved)));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/maintenance/fuel?bikeId=${widget.bikeId}');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.fuelDeleteTitle),
        content: Text(ctx.l10n.fuelDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.cancelAction)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.l10n.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await ref
        .read(fuelLogsProvider(widget.bikeId).notifier)
        .delete(widget.logId!);
    messenger.showSnackBar(SnackBar(content: Text(l10n.fuelDeleted)));
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final logs = ref.watch(fuelLogsProvider(widget.bikeId)).valueOrNull;
    // Watched so the odometer prefill can wait for the bike to load.
    ref.watch(allBikesProvider);
    ref.watch(garageProvider);
    if (logs != null) _prefill(logs);
    final title = _editing ? l10n.fuelEditTitle : l10n.fuelAddTitle;

    if (logs == null || !_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_editing)
            IconButton(
              key: const Key('fuelDelete'),
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('fuelOdometer'),
                    controller: _odometerCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.odometerKm),
                    onChanged: (_) => _kmAgoCtrl.clear(),
                    validator: (v) => _odometerError(v, logs),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('fuelDate'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(shortDate(context, _filledAt)),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
            if (!_editing) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('fuelKmAgo'),
                controller: _kmAgoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.fuelKmAgoLabel,
                  helperText: l10n.fuelKmAgoHint,
                  helperMaxLines: 2,
                  suffixText: l10n.unitDistanceKm,
                ),
                onChanged: (v) => setState(() => _onKmAgo(v)),
                validator: (v) => v == null ||
                        v.trim().isEmpty ||
                        parseLocalizedNumber(v, min: 0, max: _baseOdo) != null
                    ? null
                    : l10n.invalidNumber,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('fuelLiters'),
              controller: _litersCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: l10n.fuelLitersLabel, suffixText: l10n.unitLitre),
              onChanged: (v) => setState(() => _onTyped(_Field.liters, v)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.requiredField;
                final n = parseLocalizedNumber(v, max: 1000);
                return n == null || n <= 0 ? l10n.invalidNumber : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('fuelTotal'),
                    controller: _totalCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: l10n.fuelTotalCostLabel, prefixText: '৳ '),
                    onChanged: (v) => setState(() => _onTyped(_Field.total, v)),
                    validator: _moneyError,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: const Key('fuelPrice'),
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: l10n.fuelPricePerLiterLabel,
                        prefixText: '৳ '),
                    onChanged: (v) => setState(() => _onTyped(_Field.price, v)),
                    validator: _moneyError,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.fuelPriceHint,
                  style: TextStyle(
                      fontSize: 11.5, color: context.palette.textSecondary)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('fuelFullTank'),
              contentPadding: EdgeInsets.zero,
              value: _fullTank,
              onChanged: (v) => setState(() => _fullTank = v),
              title: Text(l10n.fuelFullTankLabel),
              subtitle: Text(l10n.fuelFullTankHint,
                  style: TextStyle(
                      fontSize: 12, color: context.palette.textSecondary)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _stationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.fuelStationLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.notesOptional),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('fuelSave'),
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.fuelSave,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
