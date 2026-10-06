import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/bike_image_resolver.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/catalog/schedule_templates.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/service_visit.dart';
import '../maintenance_l10n.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import '../widgets/edit_maintenance_check_sheet.dart' show iconForServiceType;
import '../widgets/forecast_text.dart';

/// "Log a visit": one entry per trip to the mechanic, however many jobs were
/// done (proposal: "the visit is the unit, not the item"). Everything is
/// optional and prefilled — odometer from rides, date today, last shop —
/// because tedious logging is the main reason people stop (Simply Auto's
/// case study).
///
/// Opened with `serviceType` (a check key) to start with that item ticked,
/// or with `visitId` to edit an existing visit.
class AddMaintenanceLogScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final String? initialServiceType;
  final String? visitId;
  const AddMaintenanceLogScreen({
    super.key,
    required this.bikeId,
    this.initialServiceType,
    this.visitId,
  });

  @override
  ConsumerState<AddMaintenanceLogScreen> createState() =>
      _AddMaintenanceLogScreenState();
}

/// A tickable line: a tracked check, a built-in type, or a one-off job.
class _Line {
  final ServiceType type;
  final String? checkKey;
  final String label;
  const _Line(this.type, this.checkKey, this.label);
  String get key => checkKey ?? type.name;
}

class _AddMaintenanceLogScreenState
    extends ConsumerState<AddMaintenanceLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _oilBrandCtrl = TextEditingController();
  final _oneOffCtrl = TextEditingController();
  final _ticked = <String>{};

  /// The visit's items as loaded, when editing: their labels and prices are
  /// kept even if their check has since been removed or turned off.
  final _existing = <String, MaintenanceEntity>{};
  ShopKind? _shopKind;
  OilGrade? _oilGrade;
  DateTime _date = DateTime.now();
  String? _receiptPath;
  String? _visitLabel;
  bool _showAll = false;
  bool _oneOff = false;
  bool _saving = false;
  bool _loaded = false;

  bool get _editing => widget.visitId != null;

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _costCtrl.dispose();
    _shopCtrl.dispose();
    _notesCtrl.dispose();
    _oilBrandCtrl.dispose();
    _oneOffCtrl.dispose();
    super.dispose();
  }

  /// One-time prefill once the bike, logs and forecast are available.
  void _prefill(List<MaintenanceEntity> logs, List<CheckForecast> forecasts) {
    if (_loaded) return;
    final bike = ref
        .read(garageProvider)
        .valueOrNull
        ?.where((b) => b.id == widget.bikeId)
        .firstOrNull;
    if (bike == null) return;
    _loaded = true;

    if (_editing) {
      final items = logs.where((l) => l.visitKey == widget.visitId).toList();
      if (items.isNotEmpty) {
        final v = ServiceVisit(widget.visitId!, items);
        _date = v.date;
        _odometerCtrl.text = v.odometerKm.toStringAsFixed(0);
        // The entered bill only; per-item prices stay on their items.
        final total = items.map((i) => i.visitTotal).whereType<double>().firstOrNull ??
            (items.length == 1 ? items.first.cost : null);
        if (total != null) _costCtrl.text = total.toStringAsFixed(0);
        _shopCtrl.text = v.shopName ?? '';
        _shopKind = v.shopKind;
        _notesCtrl.text = v.notes ?? '';
        _receiptPath = v.receiptPath;
        _visitLabel = v.visitLabel;
        for (final i in items) {
          _existing[i.key] = i;
          if (i.serviceType == ServiceType.custom && i.checkKey == null) {
            _oneOff = true;
            _oneOffCtrl.text = i.customLabel ?? '';
          } else {
            _ticked.add(i.key);
          }
          if (i.serviceType == ServiceType.oilChange) {
            _oilBrandCtrl.text = i.partBrand ?? '';
            _oilGrade = OilGradeExt.fromString(i.partGrade);
          }
        }
      }
      return;
    }

    _odometerCtrl.text = bike.currentOdometerKm.toStringAsFixed(0);
    final initial = widget.initialServiceType;
    if (initial != null && initial.isNotEmpty) {
      if (initial == ServiceType.custom.name) {
        _oneOff = true;
      } else {
        _ticked.add(initial);
      }
    } else {
      // Nothing chosen up front: start with what's due, the likely reason
      // for the visit.
      for (final f in forecasts) {
        if (f.needsAttention && !f.serviceType.isLowStakes) _ticked.add(f.key);
      }
    }
    // Most riders go back to the same mechanic and the same oil.
    final visits = groupVisits(logs);
    final lastShop = visits.where((v) => (v.shopName ?? '').isNotEmpty).firstOrNull;
    if (lastShop != null) {
      _shopCtrl.text = lastShop.shopName!;
      _shopKind = lastShop.shopKind;
    }
    final lastOil = latestLogFor(ServiceType.oilChange.name, logs);
    if (lastOil != null) {
      _oilBrandCtrl.text = lastOil.partBrand ?? '';
      _oilGrade = OilGradeExt.fromString(lastOil.partGrade);
    }
    _oilGrade ??=
        ref.read(maintenanceProfileProvider(widget.bikeId)).valueOrNull?.oilGrade;
  }

  List<_Line> _lines(List<MaintenanceConfigEntity> configs) =>
      _allLines(configs, includeUntracked: _showAll);

  List<_Line> _allLines(List<MaintenanceConfigEntity> configs,
      {bool includeUntracked = true}) {
    final l10n = context.l10n;
    final tracked = [
      for (final c in configs)
        if (c.isEnabled) _Line(c.serviceType, c.isCustom ? c.key : null,
            configLabel(c, l10n)),
    ];
    final trackedKeys = tracked.map((t) => t.key).toSet();
    final others = [
      for (final t in ServiceType.values)
        if (t != ServiceType.custom && !trackedKeys.contains(t.name))
          _Line(t, null, t.localizedLabel(l10n)),
    ];
    final shown = includeUntracked ? [...tracked, ...others] : tracked;
    final shownKeys = shown.map((l) => l.key).toSet();
    return [
      ...shown,
      // An edited visit's items whose check is gone or off still appear,
      // so saving doesn't silently delete them.
      for (final e in _existing.values)
        if (!shownKeys.contains(e.key) &&
            !(e.serviceType == ServiceType.custom && e.checkKey == null))
          _Line(e.serviceType, e.checkKey,
              e.checkKey != null ? (e.customLabel ?? e.serviceType.localizedLabel(l10n))
                  : e.serviceType.localizedLabel(l10n)),
    ];
  }

  void _applyBundle(ServiceBundle b, List<MaintenanceConfigEntity> configs) {
    final enabled = configs.where((c) => c.isEnabled).map((c) => c.key).toSet();
    setState(() {
      for (final t in b.types) {
        if (enabled.contains(t.name) || t == ServiceType.oilChange) {
          _ticked.add(t.name);
        }
      }
    });
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'receipts'));
      if (!await folder.exists()) await folder.create(recursive: true);
      final dest = p.join(folder.path, '${const Uuid().v4()}.jpg');
      await File(picked.path).copy(dest);
      if (mounted) setState(() => _receiptPath = dest);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.receiptPickFailed)));
    }
  }

  Future<void> _save(List<MaintenanceConfigEntity> configs) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    // Every line, not just the visible ones: an item ticked under "show
    // all" stays ticked after the list is collapsed again.
    final lines = {for (final l in _allLines(configs)) l.key: l};

    final items = <VisitItemDraft>[
      for (final key in _ticked)
        if (lines[key] != null)
          VisitItemDraft(
            type: lines[key]!.type,
            checkKey: lines[key]!.checkKey,
            customLabel: lines[key]!.checkKey != null ? lines[key]!.label : null,
            // Editing must not erase per-item prices (the ride-cost estimate
            // averages them).
            cost: _existing[key]?.cost,
            partBrand: lines[key]!.type == ServiceType.oilChange
                ? _oilBrandCtrl.text
                : null,
            partGrade: lines[key]!.type == ServiceType.oilChange
                ? _oilGrade?.name
                : null,
          ),
      if (_oneOff && _oneOffCtrl.text.trim().isNotEmpty)
        VisitItemDraft(
            type: ServiceType.custom,
            customLabel: _oneOffCtrl.text,
            cost: _existing[ServiceType.custom.name]?.cost),
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.visitPickSomething)));
      return;
    }

    setState(() => _saving = true);
    final draft = VisitDraft(
      date: _date,
      odometerKm: double.parse(_odometerCtrl.text.trim()),
      items: items,
      totalCost: double.tryParse(_costCtrl.text.trim()),
      shopName: _shopCtrl.text,
      shopKind: _shopKind,
      receiptPath: _receiptPath,
      notes: _notesCtrl.text,
      visitLabel: _visitLabel,
    );
    final notifier = ref.read(maintenanceProvider(widget.bikeId).notifier);
    final messenger = ScaffoldMessenger.of(context);
    String? newVisitId;
    if (_editing) {
      await notifier.updateVisit(widget.visitId!, draft);
    } else {
      newVisitId = await notifier.saveVisit(draft);
    }
    if (_oilGrade != null && items.any((i) => i.type == ServiceType.oilChange)) {
      await ref
          .read(maintenanceProfileProvider(widget.bikeId).notifier)
          .applyOilGrade(_oilGrade!);
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(_editing ? l10n.visitUpdated : l10n.visitSaved(items.length)),
      duration: const Duration(seconds: 10),
      action: newVisitId == null
          ? null
          : SnackBarAction(
              label: l10n.undo,
              onPressed: () => notifier.deleteVisit(newVisitId!),
            ),
    ));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/maintenance?bikeId=${widget.bikeId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final logs = ref.watch(maintenanceProvider(widget.bikeId)).valueOrNull;
    final configs = ref.watch(maintenanceConfigProvider(widget.bikeId)).valueOrNull;
    final forecasts = ref.watch(maintenanceForecastProvider(widget.bikeId));
    final profile = ref.watch(maintenanceProfileProvider(widget.bikeId)).valueOrNull;
    if (logs != null && configs != null) _prefill(logs, forecasts);

    if (logs == null || configs == null || !_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.logVisitTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lines = _lines(configs);
    final dueKeys = {
      for (final f in forecasts)
        if (f.needsAttention) f.key,
    };
    final oilTicked = _ticked.contains(ServiceType.oilChange.name);
    final template = profile?.template;
    final usedFree = groupVisits(logs)
        .map((v) => v.freeServiceNumber ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final nextFree = (template != null &&
            usedFree < template.freeServices.length &&
            !_editing)
        ? usedFree + 1
        : null;
    final shopNames = groupVisits(logs)
        .map((v) => v.shopName)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final resolvedReceipt =
        BikeImageResolver.resolvePathSync(_receiptPath);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(_editing ? l10n.editVisitTitle : l10n.logVisitTitle),
        actions: [
          if (_editing)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(ctx.l10n.deleteVisitTitle),
                    content: Text(ctx.l10n.deleteVisitBody(_existing.length)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(ctx.l10n.cancelAction)),
                      ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(ctx.l10n.delete)),
                    ],
                  ),
                );
                if (ok != true || !mounted) return;
                await ref
                    .read(maintenanceProvider(widget.bikeId).notifier)
                    .deleteVisit(widget.visitId!);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
          children: [
            if (!_editing) ...[
              EditorialLabel(l10n.quickPicks),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (nextFree != null)
                    ActionChip(
                      avatar: const Icon(Icons.card_giftcard, size: 16),
                      label: Text(l10n.freeServiceN(nextFree)),
                      backgroundColor: _visitLabel == 'free:$nextFree'
                          ? context.palette.primary.withValues(alpha: 0.15)
                          : null,
                      onPressed: () {
                        _applyBundle(ServiceBundle.generalService, configs);
                        setState(() {
                          _visitLabel = 'free:$nextFree';
                          _shopKind = ShopKind.authorized;
                        });
                      },
                    ),
                  for (final b in ServiceBundle.values)
                    ActionChip(
                      label: Text(bundleLabel(b, l10n)),
                      onPressed: () => _applyBundle(b, configs),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            EditorialLabel(l10n.whatWasDone),
            const SizedBox(height: 6),
            EditorialCard(
              radius: context.shape.radiusLg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final line in lines)
                    CheckboxListTile(
                      key: Key('visitItem_${line.key}'),
                      dense: true,
                      value: _ticked.contains(line.key),
                      onChanged: (v) => setState(() => v == true
                          ? _ticked.add(line.key)
                          : _ticked.remove(line.key)),
                      secondary: Icon(iconForServiceType(line.type),
                          size: 20,
                          color: dueKeys.contains(line.key)
                              ? context.palette.attention
                              : context.palette.textSecondary),
                      title: Text(line.label),
                      subtitle: dueKeys.contains(line.key)
                          ? Text(l10n.dueSoon,
                              style: TextStyle(
                                  fontSize: 11, color: context.palette.attention))
                          : null,
                    ),
                  CheckboxListTile(
                    dense: true,
                    value: _oneOff,
                    onChanged: (v) => setState(() => _oneOff = v ?? false),
                    secondary: Icon(Icons.handyman,
                        size: 20, color: context.palette.textSecondary),
                    title: Text(l10n.oneOffJob),
                  ),
                  if (_oneOff)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextFormField(
                        controller: _oneOffCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n.whatDidService,
                          hintText: l10n.eGRadiatorFlush,
                        ),
                        validator: (v) => _oneOff && (v == null || v.trim().isEmpty)
                            ? l10n.nameService
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? l10n.showTrackedOnly : l10n.showAllItems),
            ),

            if (oilTicked) ...[
              const SizedBox(height: 8),
              EditorialLabel(l10n.oilDetails),
              const SizedBox(height: 8),
              SuggestField(
                controller: _oilBrandCtrl,
                suggestions: kCommonOilBrands,
                label: l10n.oilBrandLabel,
                hint: l10n.eGUsedMotul,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in OilGrade.values)
                    ChoiceChip(
                      label: Text(oilGradeLabel(g, l10n)),
                      selected: _oilGrade == g,
                      onSelected: (_) => setState(() => _oilGrade = g),
                    ),
                ],
              ),
              if (_oilGrade != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.oilGradeNextChange(
                        _oilGrade!.schedule.km.toStringAsFixed(0),
                        _oilGrade!.schedule.days ?? 0),
                    style: TextStyle(
                        fontSize: 11.5, color: context.palette.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: 18),

            EditorialLabel(l10n.visitDetails),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('visitOdometer'),
                    controller: _odometerCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.odometerKm,
                      suffixText: l10n.distanceStatLabel,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.requiredField;
                      if (double.tryParse(v) == null) return l10n.invalidNumber;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(shortDate(context, _date)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && mounted) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('visitCost'),
              controller: _costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.visitTotalCost,
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 12),
            SuggestField(
              controller: _shopCtrl,
              suggestions: shopNames,
              label: l10n.shopNameLabel,
              hint: l10n.shopNameHint,
              showAllWhenEmpty: true,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final k in ShopKind.values)
                  ChoiceChip(
                    label: Text(shopKindLabel(k, l10n)),
                    selected: _shopKind == k,
                    onSelected: (sel) => setState(() => _shopKind = sel ? k : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.notesOptional),
            ),
            const SizedBox(height: 14),
            EditorialLabel(l10n.receiptLabel),
            const SizedBox(height: 8),
            if (resolvedReceipt != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.shape.radiusMd),
                    child: Image.file(File(resolvedReceipt),
                        height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filledTonal(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _receiptPath = null),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(l10n.takePhoto,
                          overflow: TextOverflow.ellipsis),
                      onPressed: () => _pickReceipt(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(l10n.fromGallery,
                          overflow: TextOverflow.ellipsis),
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('visitSave'),
              onPressed: _saving ? null : () => _save(configs),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _ticked.length + (_oneOff ? 1 : 0) > 1
                          ? l10n.saveVisitN(_ticked.length + (_oneOff ? 1 : 0))
                          : l10n.saveServiceLog,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// A text field with tap-to-fill suggestions underneath, filtered as the
/// rider types (remembered shops, common oil brands).
class SuggestField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final String label;
  final String? hint;
  final bool showAllWhenEmpty;
  const SuggestField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.label,
    this.hint,
    this.showAllWhenEmpty = false,
  });

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.controller.text.trim().toLowerCase();
    final matches = !_focus.hasFocus
        ? const <String>[]
        : widget.suggestions
            .where((s) =>
                (q.isEmpty ? widget.showAllWhenEmpty : s.toLowerCase().contains(q)) &&
                s.toLowerCase() != q)
            .take(5)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
        ),
        if (matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in matches)
                  ActionChip(
                    label: Text(m, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      widget.controller.text = m;
                      _focus.unfocus();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Engine-oil brands common in Bangladesh, for autocomplete only — the
/// rider can type anything.
const List<String> kCommonOilBrands = [
  'Motul 3000 20W-40',
  'Motul 3100 10W-30',
  'Motul 5100 10W-40',
  'Motul 7100 10W-40',
  'Mobil Super Moto 20W-40',
  'Mobil Super Moto 10W-30',
  'Shell Advance AX7 10W-40',
  'Shell Advance Long Ride 10W-40',
  'Castrol Power1 20W-40',
  'Castrol Power1 Ultimate 10W-40',
  'Yamalube 20W-40',
  'Honda 4T 10W-30',
  'Bajaj DTS-i 20W-50',
  'Total Hi-Perf 20W-40',
  'Liqui Moly Street 10W-40',
];
