import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../core/utils/image_pick.dart';
import '../../../../core/utils/parse_localized_number.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/catalog/schedule_templates.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/service_visit.dart';
import '../providers/maintenance_provider.dart';
import '../service_type_l10n.dart';
import 'maintenance_format.dart';

/// 1-Tap Quick Service Sheet: pre-filled odometer with tactile delta chips,
/// date selector, service bundles, workshop memory, quick cost chips, optional
/// receipt photo attachment, and rapid confirmation that resets wear intervals.
class QuickServiceSheet extends ConsumerStatefulWidget {
  final BikeEntity bike;
  final CheckForecast? initialForecast;
  final String? initialTitle;
  final double? initialCost;
  final ServiceType? initialServiceType;

  const QuickServiceSheet({
    super.key,
    required this.bike,
    this.initialForecast,
    this.initialTitle,
    this.initialCost,
    this.initialServiceType,
  });

  static Future<void> show(
    BuildContext context, {
    required BikeEntity bike,
    CheckForecast? initialForecast,
    String? initialTitle,
    double? initialCost,
    ServiceType? initialServiceType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickServiceSheet(
        bike: bike,
        initialForecast: initialForecast,
        initialTitle: initialTitle,
        initialCost: initialCost,
        initialServiceType: initialServiceType,
      ),
    );
  }

  @override
  ConsumerState<QuickServiceSheet> createState() => _QuickServiceSheetState();
}

class _QuickServiceSheetState extends ConsumerState<QuickServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _odometerCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _workshopCtrl;
  late final TextEditingController _oilBrandCtrl;

  late double _baseOdometer;
  DateTime _date = DateTime.now();
  int _dateChipIndex = 0; // 0: Today, 1: Yesterday, 2: 3d ago, 3: Custom
  String? _selectedBundleId;
  final Set<ServiceType> _selectedTypes = {};
  String? _customLabel;
  OilGrade? _selectedOilGrade;
  String? _receiptPath;
  bool _saving = false;

  late final bool _imperial;

  double _toDisplay(double km) => _imperial ? km * kmToMi : km;
  double _toKm(double shown) => _imperial ? shown / kmToMi : shown;

  @override
  void initState() {
    super.initState();
    _imperial = ref.read(maintenanceImperialProvider);
    _baseOdometer = _toDisplay(widget.bike.currentOdometerKm);
    _odometerCtrl = TextEditingController(
      text: _baseOdometer.toStringAsFixed(0),
    );
    _costCtrl = TextEditingController(
      text: widget.initialCost != null
          ? widget.initialCost!.toStringAsFixed(0)
          : '',
    );
    _workshopCtrl = TextEditingController();
    _oilBrandCtrl = TextEditingController();

    // Initialize selected service types
    if (widget.initialServiceType != null) {
      _selectedTypes.add(widget.initialServiceType!);
    } else if (widget.initialForecast != null) {
      _selectedTypes.add(widget.initialForecast!.serviceType);
    } else {
      _selectedBundleId = 'bundle_oil';
      _selectedTypes.addAll([ServiceType.oilChange, ServiceType.oilFilter]);
    }
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _costCtrl.dispose();
    _workshopCtrl.dispose();
    _oilBrandCtrl.dispose();
    super.dispose();
  }

  void _applyBundle(String id, String label, List<ServiceType> types) {
    setState(() {
      _selectedBundleId = id;
      _selectedTypes.clear();
      _selectedTypes.addAll(types);
      _customLabel = label;
    });
  }

  void _adjustOdometer(double delta) {
    final current = parseLocalizedNumber(_odometerCtrl.text) ?? _baseOdometer;
    final updated = (current + delta).clamp(0.0, 999999.0);
    setState(() {
      _odometerCtrl.text = updated.toStringAsFixed(0);
    });
  }

  void _setDatePreset(int index) {
    final now = DateTime.now();
    setState(() {
      _dateChipIndex = index;
      if (index == 0) {
        _date = now;
      } else if (index == 1) {
        _date = now.subtract(const Duration(days: 1));
      } else if (index == 2) {
        _date = now.subtract(const Duration(days: 3));
      }
    });
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateChipIndex = 3;
      });
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await ignoreActivePicker(
        picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600),
      );
      if (xfile == null || !mounted) return;

      final dir = await getApplicationDocumentsDirectory();
      final receiptDir = Directory(p.join(dir.path, 'receipts'));
      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }
      final filename =
          'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(xfile.path)}';
      final savedFile =
          await File(xfile.path).copy(p.join(receiptDir.path, filename));

      setState(() => _receiptPath = savedFile.path);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'Quick service: receipt capture failed');
    }
  }

  Future<void> _submit() async {
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.visitPickSomething)),
      );
      return;
    }

    setState(() => _saving = true);
    final odo = parseLocalizedNumber(_odometerCtrl.text) ?? _baseOdometer;
    final cost = parseLocalizedNumber(_costCtrl.text);
    final workshop = _workshopCtrl.text.trim();
    final oilBrand = _oilBrandCtrl.text.trim();

    final items = <VisitItemDraft>[
      for (final type in _selectedTypes)
        VisitItemDraft(
          type: type,
          cost: _selectedTypes.length == 1 ? cost : null,
          partBrand: type == ServiceType.oilChange && oilBrand.isNotEmpty
              ? oilBrand
              : null,
          partGrade: type == ServiceType.oilChange && _selectedOilGrade != null
              ? _selectedOilGrade!.name
              : null,
          customLabel: type == ServiceType.custom ? _customLabel : null,
        ),
    ];

    final draft = VisitDraft(
      date: _date,
      odometerKm: _toKm(odo),
      items: items,
      totalCost: cost,
      shopName: workshop.isNotEmpty ? workshop : null,
      // No guessing a shop kind from its name: set it in Log a visit.
      receiptPath: _receiptPath,
    );

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final l10n = context.l10n;

    try {
      final notifier = ref.read(maintenanceProvider(widget.bike.id).notifier);
      await notifier.saveVisit(draft);

      // If entered odometer is higher than bike's known current odometer, sync it
      final odoKm = _toKm(odo);
      if (odoKm > widget.bike.currentOdometerKm) {
        await ref.read(garageProvider.notifier).syncOdometer(
              bikeId: widget.bike.id,
              newOdometerKm: odoKm,
            );
      }

      // If oil grade changed
      if (_selectedOilGrade != null &&
          _selectedTypes.contains(ServiceType.oilChange)) {
        await ref
            .read(maintenanceProfileProvider(widget.bike.id).notifier)
            .applyOilGrade(_selectedOilGrade!);
      }

      if (!mounted) return;
      nav.pop();

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: context.palette.surfaceVariant,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.check_circle,
                  color: context.palette.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✓ Service visit logged at ${odo.toStringAsFixed(0)} ${_imperial ? 'mi' : 'km'}. Wear interval reset.',
                  style: TextStyle(color: context.palette.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'Quick service: save failed');
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.visitSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = context.shape;
    final l10n = context.l10n;
    final hasOil = _selectedTypes.contains(ServiceType.oilChange);
    final earlierLogs =
        ref.watch(maintenanceProvider(widget.bike.id)).valueOrNull ?? const [];
    final shownOdo = parseLocalizedNumber(_odometerCtrl.text, min: 0);
    final odoLow = shownOdo != null &&
        odometerBelowEarlierLog(
            odometerKm: _toKm(shownOdo), date: _date, logs: earlierLogs);
    final shopNames = groupVisits(
            ref.watch(maintenanceProvider(widget.bike.id)).valueOrNull ??
                const [])
        .map((v) => v.shopName)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final displayTitle = widget.initialTitle ??
        (_customLabel ??
            (_selectedTypes.isNotEmpty
                ? _selectedTypes.first.localizedLabel(l10n)
                : l10n.logVisitTitle));

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: palette.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(shape.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sheet Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOG SERVICE: ${displayTitle.toUpperCase()}',
                          style: AppTypography.display(context, 16,
                              weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '1-tap service completion, bundles & receipt snap',
                          style: TextStyle(
                              fontSize: 12, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: palette.textTertiary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Service Bundles Chips
              const _SectionLabel(label: 'Service Bundles (1-Tap Selection)'),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SelectableChip(
                      label: 'Oil + Filter',
                      selected: _selectedBundleId == 'bundle_oil',
                      onTap: () => _applyBundle(
                        'bundle_oil',
                        'Oil + Filter',
                        [ServiceType.oilChange, ServiceType.oilFilter],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SelectableChip(
                      label: 'Chain Service',
                      selected: _selectedBundleId == 'bundle_chain',
                      onTap: () => _applyBundle(
                        'bundle_chain',
                        'Chain Service',
                        [ServiceType.chain],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SelectableChip(
                      label: 'Full Overhaul',
                      selected: _selectedBundleId == 'bundle_overhaul',
                      onTap: () => _applyBundle(
                        'bundle_overhaul',
                        'Full Overhaul',
                        [
                          ServiceType.oilChange,
                          ServiceType.oilFilter,
                          ServiceType.chain,
                          ServiceType.brakeFluid,
                          ServiceType.airFilter,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Service Odometer Field & Delta Chips
              _SectionLabel(
                  label: _imperial
                      ? 'Service Odometer (MI)'
                      : 'Service Odometer (KM)'),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('quickServiceOdometerField'),
                controller: _odometerCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: GoogleFonts.ibmPlexMono(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    borderSide: BorderSide(color: palette.primary),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  helperText: odoLow ? l10n.visitOdometerBelowEarlier : null,
                  helperMaxLines: 3,
                  suffixText: _imperial ? 'MI' : 'KM',
                  suffixStyle: GoogleFonts.ibmPlexMono(
                      color: palette.textTertiary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionChip(
                        label: '-100 ${_imperial ? 'mi' : 'km'}',
                        onTap: () => _adjustOdometer(-100)),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '-50 ${_imperial ? 'mi' : 'km'}',
                        onTap: () => _adjustOdometer(-50)),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: 'Current (${_baseOdometer.toStringAsFixed(0)})',
                      isHighlight: true,
                      onTap: () {
                        setState(() => _odometerCtrl.text =
                            _baseOdometer.toStringAsFixed(0));
                      },
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '+50 ${_imperial ? 'mi' : 'km'}',
                        onTap: () => _adjustOdometer(50)),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '+100 ${_imperial ? 'mi' : 'km'}',
                        onTap: () => _adjustOdometer(100)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date Selection Chips
              const _SectionLabel(label: 'Service Date'),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SelectableChip(
                      label: 'Today',
                      selected: _dateChipIndex == 0,
                      onTap: () => _setDatePreset(0),
                    ),
                    const SizedBox(width: 8),
                    _SelectableChip(
                      label: 'Yesterday',
                      selected: _dateChipIndex == 1,
                      onTap: () => _setDatePreset(1),
                    ),
                    const SizedBox(width: 8),
                    _SelectableChip(
                      label: '3 Days Ago',
                      selected: _dateChipIndex == 2,
                      onTap: () => _setDatePreset(2),
                    ),
                    const SizedBox(width: 8),
                    _SelectableChip(
                      label: _dateChipIndex == 3
                          ? '${_date.day}/${_date.month}/${_date.year}'
                          : 'Custom Date...',
                      selected: _dateChipIndex == 3,
                      onTap: _pickCustomDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Oil Brand & Grade Context (Shown when Oil Change is in bundle)
              if (hasOil) ...[
                const _SectionLabel(label: 'Engine Oil Brand & Grade'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _oilBrandCtrl,
                  style: GoogleFonts.ibmPlexSans(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: palette.surfaceVariant,
                    hintText: 'e.g. Motul 7100 10W-40, Yamalube Semi-Synth',
                    hintStyle:
                        TextStyle(color: palette.textTertiary, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(shape.radiusSm),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SelectableChip(
                        label: 'Motul 7100',
                        selected: _oilBrandCtrl.text.contains('Motul 7100'),
                        onTap: () => setState(() => _oilBrandCtrl.text =
                            'Motul 7100 10W-40 Full Synthetic'),
                      ),
                      const SizedBox(width: 6),
                      _SelectableChip(
                        label: 'Yamalube SL',
                        selected: _oilBrandCtrl.text.contains('Yamalube'),
                        onTap: () => setState(() => _oilBrandCtrl.text =
                            'Yamalube 10W-40 Semi-Synthetic'),
                      ),
                      const SizedBox(width: 6),
                      _SelectableChip(
                        label: 'Castrol Power1',
                        selected: _oilBrandCtrl.text.contains('Castrol'),
                        onTap: () => setState(
                            () => _oilBrandCtrl.text = 'Castrol Power1 10W-40'),
                      ),
                      const SizedBox(width: 6),
                      _SelectableChip(
                        label: 'Shell Advance',
                        selected: _oilBrandCtrl.text.contains('Shell Advance'),
                        onTap: () => setState(() =>
                            _oilBrandCtrl.text = 'Shell Advance Ultra 10W-40'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Workshop Selector
              const _SectionLabel(label: 'Workshop Name (Remembered)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _workshopCtrl,
                style: GoogleFonts.ibmPlexSans(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: PopupMenuButton<String>(
                    icon: Icon(Icons.arrow_drop_down,
                        color: palette.textSecondary),
                    onSelected: (val) =>
                        setState(() => _workshopCtrl.text = val),
                    itemBuilder: (ctx) => shopNames
                        .map((w) => PopupMenuItem(
                            value: w,
                            child:
                                Text(w, style: const TextStyle(fontSize: 13))))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Invoice Total & Quick Cost Chips
              const _SectionLabel(label: 'Invoice Total (BDT ৳)'),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('quickServiceCostField'),
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.ibmPlexMono(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixText: '৳ ',
                  prefixStyle: GoogleFonts.ibmPlexMono(
                      color: palette.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionChip(
                        label: '৳0 (Free)',
                        onTap: () => setState(() => _costCtrl.text = '0')),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '৳250',
                        onTap: () => setState(() => _costCtrl.text = '250')),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '৳650',
                        onTap: () => setState(() => _costCtrl.text = '650')),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '৳1,200',
                        onTap: () => setState(() => _costCtrl.text = '1200')),
                    const SizedBox(width: 6),
                    _ActionChip(
                        label: '৳2,500',
                        onTap: () => setState(() => _costCtrl.text = '2500')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Receipt Photo Attachment
              const _SectionLabel(label: 'Workshop Receipt (Optional)'),
              const SizedBox(height: 6),
              if (_receiptPath == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('SNAP INVOICE',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textSecondary,
                          side: BorderSide(color: palette.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(shape.radiusSm)),
                        ),
                        onPressed: () => _pickReceipt(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('GALLERY',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textSecondary,
                          side: BorderSide(color: palette.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(shape.radiusSm)),
                        ),
                        onPressed: () => _pickReceipt(ImageSource.gallery),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(shape.radiusSm),
                    border: Border.all(
                        color: palette.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long,
                          color: palette.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.basename(_receiptPath!),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.success,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _receiptPath = null),
                        child:
                            Icon(Icons.close, color: palette.danger, size: 18),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Rapid Confirmation Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('quickServiceConfirmButton'),
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: palette.primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(shape.radiusMd),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          '✓ CONFIRM & RECALIBRATE FORECAST',
                          style: AppTypography.display(
                            context,
                            13,
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.ibmPlexMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: context.palette.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.shape.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.15)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool isHighlight;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.shape.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isHighlight
              ? palette.primary.withValues(alpha: 0.12)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(context.shape.radiusFull),
          border: Border.all(
            color: isHighlight ? palette.primary : palette.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isHighlight ? palette.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
