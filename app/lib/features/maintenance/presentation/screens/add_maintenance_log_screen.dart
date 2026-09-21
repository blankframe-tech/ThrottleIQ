import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/maintenance_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../service_type_l10n.dart';

class AddMaintenanceLogScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final String? initialServiceType;
  const AddMaintenanceLogScreen({
    super.key,
    required this.bikeId,
    this.initialServiceType,
  });

  @override
  ConsumerState<AddMaintenanceLogScreen> createState() => _AddMaintenanceLogScreenState();
}

class _AddMaintenanceLogScreenState extends ConsumerState<AddMaintenanceLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _customLabelCtrl = TextEditingController();
  late ServiceType _selectedType;
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialServiceType != null
        ? ServiceTypeExt.fromString(widget.initialServiceType!)
        : ServiceType.oilChange;

    // Pre-fill odometer from bike stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bikes = ref.read(garageProvider).valueOrNull ?? [];
      final bike = bikes.where((b) => b.id == widget.bikeId).firstOrNull;
      if (bike != null) {
        _odometerCtrl.text = bike.currentOdometerKm.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    _customLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(primary: ctx.palette.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await ref.read(maintenanceProvider(widget.bikeId).notifier).addLog(
          bikeId: widget.bikeId,
          serviceType: _selectedType,
          date: _date,
          odometerKm: double.parse(_odometerCtrl.text),
          cost: _costCtrl.text.isNotEmpty ? double.tryParse(_costCtrl.text) : null,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
          customLabel:
              _selectedType == ServiceType.custom ? _customLabelCtrl.text : null,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n.logServiceTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.serviceType,
                  style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ServiceType.values.map((type) {
                  final selected = type == _selectedType;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.palette.primary.withValues(alpha: 0.15)
                            : context.palette.surface,
                        borderRadius: BorderRadius.circular(context.shape.radiusFull),
                        border: Border.all(
                          color: selected ? context.palette.primary : context.palette.border,
                        ),
                      ),
                      child: Text(
                        type.localizedLabel(context.l10n),
                        style: TextStyle(
                            fontSize: 13,
                            color: selected ? context.palette.primary : context.palette.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // "Custom" on its own says nothing six months later, so naming
              // it is required rather than optional once that chip is picked.
              if (_selectedType == ServiceType.custom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customLabelCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: context.palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.whatDidService,
                    hintText: context.l10n.eGRadiatorFlush,
                  ),
                  validator: (v) {
                    if (_selectedType != ServiceType.custom) return null;
                    if (v == null || v.trim().isEmpty) {
                      return context.l10n.nameService;
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              // Date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(context.shape.radiusMd),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: context.palette.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        '${_date.day}/${_date.month}/${_date.year}',
                        style: TextStyle(color: context.palette.textPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          color: context.palette.textTertiary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _odometerCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.palette.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.odometerKm,
                  suffixText: context.l10n.distanceStatLabel,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return context.l10n.requiredField;
                  if (double.tryParse(v) == null) return context.l10n.invalidNumber;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.palette.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.costOptional,
                  prefixText: '৳ ',
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final configs = ref
                          .watch(maintenanceConfigProvider(widget.bikeId))
                          .valueOrNull ??
                      [];
                  final currentConfig = configs
                      .where((c) => c.serviceType == _selectedType)
                      .firstOrNull;
                  final specNote = currentConfig?.notes;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        style: TextStyle(color: context.palette.textPrimary),
                        decoration: InputDecoration(
                          labelText: context.l10n.notesOptional,
                          hintText: (specNote != null && specNote.isNotEmpty)
                              ? context.l10n.configuredSpec(specNote)
                              : (_selectedType == ServiceType.fuel
                                  ? context.l10n.eGOctane95
                                  : context.l10n.eGUsedMotul),
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (specNote != null && specNote.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            if (_notesCtrl.text.isEmpty) {
                              _notesCtrl.text = specNote;
                            } else if (!_notesCtrl.text.contains(specNote)) {
                              _notesCtrl.text =
                                  '${_notesCtrl.text} ($specNote)';
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.palette.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                  context.shape.radiusSm),
                              border: Border.all(
                                  color: context.palette.primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 12, color: context.palette.primary),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.insertSpec(specNote),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.palette.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(context.l10n.saveServiceLog),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
