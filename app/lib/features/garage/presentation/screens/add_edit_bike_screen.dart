import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/bike_colors.dart';
import '../../../../core/utils/image_crop_io.dart';
import '../../../../shared/screens/image_crop_screen.dart';
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
  final _odometerCtrl = TextEditingController();
  String? _imagePath;
  int? _colorValue;
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
      _odometerCtrl.text = _existingBike!.odometerKm?.toString() ?? '';
      _imagePath = _existingBike!.imagePath;
      _colorValue = _existingBike!.colorValue;
      setState(() {});
    }
  }

  /// Pick a photo, then crop it.
  ///
  /// The crop step is offered, not forced: cancelling out of the cropper keeps
  /// the photo as picked rather than throwing the whole selection away, since
  /// "I picked the right photo but don't need to crop it" is the common case
  /// and having to re-pick would be a punishment for tapping Cancel.
  ///
  /// `imageQuality: 80` stays on the pick so an enormous original is shrunk
  /// before it is ever decoded; the cropper re-encodes at 90 from whatever it
  /// receives, so cropping doesn't compound the loss much.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null || !mounted) return;

    final cropped = await ImageCropScreen.open(
      context,
      sourcePath: xfile.path,
      title: 'Crop bike photo',
    );
    if (!mounted) return;
    if (cropped != null) {
      setState(() => _imagePath = cropped);
      return;
    }
    // Skipping the crop keeps the photo as picked rather than throwing the
    // selection away, but `xfile.path` itself lives in ImagePicker's own
    // cache directory — not guaranteed to survive an app rebuild/reinstall
    // or OS cleanup (see `persistPickedImage`) — so it still has to be
    // copied into the app's own storage before it's saved as `imagePath`.
    final persisted =
        await persistPickedImage(sourcePath: xfile.path, filePrefix: 'bike');
    if (!mounted) return;
    setState(() => _imagePath = persisted);
  }

  /// Re-crop a photo that's already attached — reachable from the "Crop"
  /// button under the preview. Without this, adjusting a crop means picking
  /// the photo out of the library again.
  Future<void> _cropCurrent() async {
    final path = _imagePath;
    if (path == null) return;

    final cropped = await ImageCropScreen.open(
      context,
      sourcePath: path,
      title: 'Crop bike photo',
    );
    if (cropped == null || !mounted) return;
    setState(() => _imagePath = cropped);
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
              odometerKm: double.tryParse(_odometerCtrl.text),
              colorValue: _colorValue,
              clearColor: _colorValue == null,
            ),
          );
    } else {
      await ref.read(garageProvider.notifier).addBike(
            brand: _brandCtrl.text.trim(),
            model: _modelCtrl.text.trim(),
            year: int.tryParse(_yearCtrl.text),
            cc: int.tryParse(_ccCtrl.text),
            imagePath: _imagePath,
            odometerKm: double.tryParse(_odometerCtrl.text),
            colorValue: _colorValue,
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
    _odometerCtrl.dispose();
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
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
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
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.textSecondary, size: 28),
                              SizedBox(height: 6),
                              Text('Add Photo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              // Only offered once there's a photo to act on. "Crop" is
              // separate from "Replace" because re-framing the photo you
              // already chose shouldn't send you back into the library.
              if (_imagePath != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _cropCurrent,
                      icon: const Icon(Icons.crop, size: 18),
                      label: const Text('Crop'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Replace'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _brandCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Brand *', hintText: 'Yamaha'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Model *', hintText: 'MT-15'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          labelText: 'Year', hintText: '2023'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ccCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          labelText: 'Engine CC', hintText: '155'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _odometerCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Odometer reading (km)', hintText: '12000'),
              ),
              const SizedBox(height: 20),
              Text('Bike color',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _ColorSwatchPicker(
                selected: _colorValue,
                onChanged: (value) => setState(() => _colorValue = value),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Add Bike'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of preset paint-color swatches, plus an "Auto" tile that clears the
/// pick — the rider isn't forced to know their bike's exact color to still
/// get a distinct one (see [bikeAccentColor]'s id-based fallback).
class _ColorSwatchPicker extends StatelessWidget {
  const _ColorSwatchPicker({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _AutoTile(isSelected: selected == null, onTap: () => onChanged(null)),
        for (final color in bikeColorPalette)
          _SwatchTile(
            color: color,
            isSelected: selected == color.toARGB32(),
            onTap: () => onChanged(color.toARGB32()),
          ),
      ],
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile(
      {required this.color, required this.isSelected, required this.onTap});

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _ColorSwatchPicker._size,
        height: _ColorSwatchPicker._size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

class _AutoTile extends StatelessWidget {
  const _AutoTile({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _ColorSwatchPicker._size,
        height: _ColorSwatchPicker._size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : AppColors.border,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child:
            Icon(Icons.auto_awesome, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}
