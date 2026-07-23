import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/map_location_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/place_repository.dart';
import '../../data/utils/geohash_utils.dart';
import '../../domain/entities/place_entity.dart';
import '../providers/places_provider.dart';

/// Same Dhaka fallback center used by `ride_summary_screen.dart` when no
/// real fix is available yet.
const _fallbackCenter = LatLng(23.8103, 90.4125);

/// "Add a place" form — the location defaults to the rider's current GPS fix
/// but can be moved anywhere via the map pin picker, computes its geohash
/// from wherever the pin ends up, and creates it via [PlaceRepository.addPlace].
class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  PlaceCategory _selectedCategory = PlaceCategory.fuel;
  bool _submitting = false;
  LatLng? _pickedLocation;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final location = _pickedLocation ?? _fallbackCenter;

    setState(() => _submitting = true);
    try {
      final geohash = GeohashUtils.encode(location.latitude, location.longitude);

      final place = PlaceEntity(
        id: '', // Firestore assigns the id via addPlace()'s collection.add().
        name: _nameCtrl.text.trim(),
        category: _selectedCategory,
        latitude: location.latitude,
        longitude: location.longitude,
        geohash: geohash,
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        hours: _hoursCtrl.text.trim().isEmpty ? null : _hoursCtrl.text.trim(),
        createdBy: uid,
        createdAt: DateTime.now(),
      );

      await PlaceRepository().addPlace(place);

      // Pop BEFORE invalidating: this screen is pushed on top of
      // PlacesListScreen (same Navigator), and nearbyPlacesProvider drives
      // PlacesListScreen.build's placesAsync.when directly — invalidating
      // it swaps that screen's list for a loading spinner. Doing that
      // subtree swap in the same tick as popping the route above it races
      // the two tree mutations against each other, the same trigger behind
      // forum_thread_screen.dart's "'_dependents.isEmpty': is not true"
      // InheritedElement assertion crash. Popping first lets the route
      // removal settle before the revealed screen rebuilds.
      if (mounted) context.pop();

      // A brand-new place isn't in any cached nearbyPlacesProvider result
      // yet — invalidate the whole family (all category keys) so the
      // Places tab picks it up right away rather than showing a stale list
      // until some unrelated refetch happens.
      ref.invalidate(nearbyPlacesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add place: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(currentPositionProvider);
    final initialCenter = positionAsync.valueOrNull != null
        ? LatLng(positionAsync.valueOrNull!.latitude, positionAsync.valueOrNull!.longitude)
        : _fallbackCenter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Place')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Location', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              MapLocationPicker(
                // Keyed by center so the map remounts (and re-centers) once
                // a real GPS fix replaces the Dhaka fallback — FlutterMap's
                // initialCenter is only read once per widget instance, not
                // reactive to prop changes on an already-mounted map.
                key: ValueKey(initialCenter),
                initialCenter: initialCenter,
                onLocationChanged: (latLng) => _pickedLocation = latLng,
              ),
              const SizedBox(height: 20),
              const Text('Category', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PlaceCategory.values.map((category) {
                  final selected = category == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(category.icon, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            category.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              color: selected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Rahman Motors'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Address *', hintText: 'Street, area, city'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Phone (optional)', hintText: '+880...'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hoursCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Hours (optional)',
                  hintText: 'e.g. 9am - 9pm, or 24/7',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Place'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
