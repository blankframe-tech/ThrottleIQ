import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/garage_provider.dart';
import '../../domain/entities/bike_entity.dart';

class AddEditBikeScreen extends ConsumerStatefulWidget {
  final String? bikeId;
  const AddEditBikeScreen({super.key, this.bikeId});

  @override
  ConsumerState<AddEditBikeScreen> createState() => _AddEditBikeScreenState();
}

class _AddEditBikeScreenState extends ConsumerState<AddEditBikeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  String? _imagePath;
  bool _loading = false;
  BikeEntity? _existingBike;

  @override
  void initState() {
    super.initState();
    if (widget.bikeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBike());
    }
  }

  void _loadBike() {
    final bikes = ref.read(garageProvider).valueOrNull ?? [];
    _existingBike = bikes.where((b) => b.id == widget.bikeId).firstOrNull;
    if (_existingBike != null) {
      _brandCtrl.text = _existingBike!.brand;
      _modelCtrl.text = _existingBike!.model;
      _yearCtrl.text = _existingBike!.year?.toString() ?? '';
      _ccCtrl.text = _existingBike!.cc?.toString() ?? '';
      _imagePath = _existingBike!.imagePath;
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile != null) setState(() => _imagePath = xfile.path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_existingBike != null) {
      await ref.read(garageProvider.notifier).updateBike(
            _existingBike!.copyWith(
              brand: _brandCtrl.text.trim(),
              model: _modelCtrl.text.trim(),
              year: int.tryParse(_yearCtrl.text),
              cc: int.tryParse(_ccCtrl.text),
              imagePath: _imagePath,
            ),
          );
    } else {
      await ref.read(garageProvider.notifier).addBike(
            brand: _brandCtrl.text.trim(),
            model: _modelCtrl.text.trim(),
            year: int.tryParse(_yearCtrl.text),
            cc: int.tryParse(_ccCtrl.text),
            imagePath: _imagePath,
          );
    }

    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _ccCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bikeId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Bike' : 'Add Bike'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      border: Border.all(color: AppColors.border),
                      image: _imagePath != null
                          ? DecorationImage(
                              image: FileImage(File(_imagePath!)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.textSecondary, size: 28),
                              SizedBox(height: 6),
                              Text('Add Photo',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _brandCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Brand *', hintText: 'Yamaha'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Model *', hintText: 'MT-15'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Year', hintText: '2023'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ccCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Engine CC', hintText: '155'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Add Bike'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
