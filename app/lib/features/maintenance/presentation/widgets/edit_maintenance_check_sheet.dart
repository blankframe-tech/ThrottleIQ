import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../providers/maintenance_provider.dart';

IconData iconForServiceType(ServiceType type) {
  switch (type) {
    case ServiceType.fuel:
      return Icons.local_gas_station;
    case ServiceType.oilChange:
    case ServiceType.oilFilter:
      return Icons.opacity;
    case ServiceType.airFilter:
      return Icons.air;
    case ServiceType.chain:
    case ServiceType.chainTension:
      return Icons.link;
    case ServiceType.tire:
      return Icons.tire_repair;
    case ServiceType.frontDiscPads:
    case ServiceType.rearDrumPads:
    case ServiceType.brakeFluid:
    case ServiceType.brakeRotors:
      return Icons.disc_full;
    case ServiceType.sparkPlug:
      return Icons.electric_bolt;
    case ServiceType.battery:
      return Icons.battery_charging_full;
    case ServiceType.radiatorCoolant:
      return Icons.water_drop;
    case ServiceType.clutchCable:
    case ServiceType.throttleCables:
      return Icons.tune;
    case ServiceType.valveClearance:
      return Icons.build;
    case ServiceType.suspension:
    case ServiceType.forkSeals:
      return Icons.vertical_align_center;
    case ServiceType.wheelBearings:
    case ServiceType.driveBelt:
      return Icons.album;
    case ServiceType.custom:
      return Icons.handyman;
  }
}

String extraInfoHintForServiceType(ServiceType type) {
  switch (type) {
    case ServiceType.fuel:
      return 'e.g. Octane 95, Shell V-Power, 14L tank capacity';
    case ServiceType.oilChange:
      return 'e.g. Motul 7100 10W-40 Synthetic (1.2L)';
    case ServiceType.oilFilter:
      return 'e.g. K&N KN-204-1, OEM 16097-0008';
    case ServiceType.tire:
      return 'e.g. Front: 110/70 R17 (DOT 2423), Rear: 140/70 R17 (DOT 3023)';
    case ServiceType.chain:
      return 'e.g. DID 520 X-Ring (114 links), Motul chain paste';
    case ServiceType.chainTension:
      return 'e.g. 25-30 mm slack on side stand';
    case ServiceType.brakeFluid:
      return 'e.g. Motul DOT 5.1 / DOT 4 hydraulic fluid';
    case ServiceType.frontDiscPads:
      return 'e.g. Brembo Sintered 07BB38SA';
    case ServiceType.rearDrumPads:
      return 'e.g. Nissin OEM Rear Pads / Shoes';
    case ServiceType.sparkPlug:
      return 'e.g. NGK CPR8EA-9, 0.8-0.9mm gap';
    case ServiceType.battery:
      return 'e.g. Yuasa YTX9-BS 12V 8Ah AGM';
    case ServiceType.radiatorCoolant:
      return 'e.g. Motul Motocool Expert 50:50 Premix';
    case ServiceType.airFilter:
      return 'e.g. BMC / K&N washable air filter element';
    default:
      return 'e.g. Brand, specs, part numbers, manufacture dates, notes...';
  }
}

List<int> presetIntervalsForServiceType(ServiceType type) {
  switch (type) {
    case ServiceType.fuel:
      return [200, 250, 300, 350, 400];
    case ServiceType.chain:
      return [400, 500, 600, 800, 1000];
    case ServiceType.chainTension:
      return [500, 1000, 1500, 2000];
    case ServiceType.oilChange:
      return [1000, 1500, 2000, 2500, 3000, 5000];
    case ServiceType.tire:
      return [2000, 3000, 5000, 8000];
    case ServiceType.battery:
      return [3000, 5000, 6000, 10000];
    case ServiceType.airFilter:
      return [4000, 6000, 8000, 12000];
    case ServiceType.sparkPlug:
      return [6000, 8000, 10000, 15000];
    case ServiceType.frontDiscPads:
    case ServiceType.rearDrumPads:
      return [8000, 10000, 12000, 15000];
    default:
      return [1000, 1500, 3000, 5000, 10000, 15000];
  }
}

class EditMaintenanceCheckSheet extends ConsumerStatefulWidget {
  final MaintenanceConfigEntity config;
  final bool persistImmediately;

  const EditMaintenanceCheckSheet({
    super.key,
    required this.config,
    this.persistImmediately = true,
  });

  static Future<MaintenanceConfigEntity?> show(
    BuildContext context, {
    required MaintenanceConfigEntity config,
    bool persistImmediately = true,
  }) {
    return showModalBottomSheet<MaintenanceConfigEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditMaintenanceCheckSheet(
        config: config,
        persistImmediately: persistImmediately,
      ),
    );
  }

  @override
  ConsumerState<EditMaintenanceCheckSheet> createState() =>
      _EditMaintenanceCheckSheetState();
}

class _EditMaintenanceCheckSheetState
    extends ConsumerState<EditMaintenanceCheckSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _intervalCtrl;
  late final TextEditingController _notesCtrl;
  late bool _isEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _intervalCtrl = TextEditingController(
      text: widget.config.intervalKm.toStringAsFixed(0),
    );
    _notesCtrl = TextEditingController(text: widget.config.notes ?? '');
    _isEnabled = widget.config.isEnabled;
  }

  @override
  void dispose() {
    _intervalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final intervalVal = double.tryParse(_intervalCtrl.text.trim());
    if (intervalVal == null || intervalVal <= 0) return;

    final trimmedNotes = _notesCtrl.text.trim();
    final updated = widget.config.copyWith(
      intervalKm: intervalVal,
      isEnabled: _isEnabled,
      notes: trimmedNotes.isNotEmpty ? trimmedNotes : null,
    );

    if (widget.persistImmediately) {
      setState(() => _saving = true);
      await ref
          .read(maintenanceConfigProvider(widget.config.bikeId).notifier)
          .updateSingleConfig(updated);
      if (!mounted) return;
    }

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.config.serviceType;
    final icon = iconForServiceType(type);
    final presets = presetIntervalsForServiceType(type);
    final hint = extraInfoHintForServiceType(type);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMd,
        14,
        AppDimensions.paddingMd,
        bottomInset + AppDimensions.paddingMd,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header with Service Icon & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.label, style: display(18)),
                        const SizedBox(height: 2),
                        Text(
                          type.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Enable / Disable Tracking Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track on Dashboard',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Calculate wear and monitor interval',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isEnabled,
                      onChanged: (v) => setState(() => _isEnabled = v),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Service Interval
              EditorialLabel('Service Interval'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _intervalCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Interval Distance (km)',
                  suffixText: 'km',
                  prefixIcon: const Icon(Icons.speed, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Preset Interval Quick Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((km) {
                  final matches =
                      _intervalCtrl.text.trim() == km.toString();
                  return ActionChip(
                    label: Text(
                      '$km km',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            matches ? FontWeight.w700 : FontWeight.normal,
                        color: matches
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _intervalCtrl.text = km.toString();
                      });
                    },
                    backgroundColor: matches
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    side: BorderSide(
                      color: matches ? AppColors.primary : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Specifications & Extra Info Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EditorialLabel('Specifications & Extra Info'),
                  Text(
                    'Optional text',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Specs (oil grade, tyre sizes & dates...)',
                  hintText: hint,
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.edit_note, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Visible on your maintenance card for quick reference.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Cancel and Save
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
