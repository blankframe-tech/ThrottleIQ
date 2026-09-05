import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/maintenance_provider.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';

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
          colorScheme: ColorScheme.dark(primary: AppColors.primary),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Log Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Service Type',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        type.label,
                        style: TextStyle(
                            fontSize: 13,
                            color: selected ? AppColors.primary : AppColors.textSecondary,
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
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'What did you service? *',
                    hintText: 'e.g. Radiator flush',
                  ),
                  validator: (v) {
                    if (_selectedType != ServiceType.custom) return null;
                    if (v == null || v.trim().isEmpty) {
                      return 'Name the service';
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        '${_date.day}/${_date.month}/${_date.year}',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          color: AppColors.textTertiary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _odometerCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Odometer (km) *',
                  suffixText: 'km',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Cost (optional)',
                  prefixText: '৳ ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Used Motul 10W40...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Service Log'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
