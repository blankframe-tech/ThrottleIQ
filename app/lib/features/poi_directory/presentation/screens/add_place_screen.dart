import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/map_location_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/place_repository.dart';
import '../../data/services/nominatim_service.dart';
import '../../data/utils/geohash_utils.dart';
import '../../data/utils/image_compression_utils.dart';
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

  /// Local path of the one optional photo. Null means "no photo" — which is
  /// a perfectly valid submission, not an incomplete one.
  String? _photoPath;

  /// True while the "use the pin's location" reverse-geocode is in flight.
  bool _lookingUpAddress = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  /// Offers camera or gallery, then stores the chosen path. Cancelling at
  /// either step leaves the form exactly as it was — the photo is optional,
  /// so backing out is a normal outcome, never an error.
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: Text('Take a photo',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text('Choose from gallery',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final xfile =
          await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (xfile == null || !mounted) return;
      setState(() => _photoPath = xfile.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the camera or gallery: $e')),
      );
    }
  }

  /// Best-effort reverse geocode of wherever the pin currently sits, used to
  /// give the (optional) address field a starting point. Explicitly
  /// rider-triggered rather than firing on every map pan — see
  /// [NominatimService].
  Future<void> _fillAddressFromPin() async {
    if (_lookingUpAddress) return;
    final location = _pickedLocation ?? _fallbackCenter;

    setState(() => _lookingUpAddress = true);
    try {
      final suggestion = await NominatimService().reverseGeocode(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      if (suggestion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Couldn't look that spot up — just describe it yourself."),
          ),
        );
        return;
      }
      // Overwrites rather than appends: the rider asked for the pin's
      // address, and anything already typed was their own earlier draft.
      _addressCtrl.text = suggestion;
      _addressCtrl.selection =
          TextSelection.collapsed(offset: suggestion.length);
    } finally {
      if (mounted) setState(() => _lookingUpAddress = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final location = _pickedLocation ?? _fallbackCenter;

    setState(() => _submitting = true);
    try {
      final geohash = GeohashUtils.encode(location.latitude, location.longitude);

      // The photo is a nice-to-have, so a failed upload must not cost the
      // rider the whole submission — warn and save the place without it.
      final photoUrls = <String>[];
      if (_photoPath != null) {
        try {
          final compressed =
              await ImageCompressionUtils.compressImage(_photoPath!);
          photoUrls.add(await PlaceRepository()
              .uploadPlacePhoto(uid, compressed ?? File(_photoPath!)));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Photo didn't upload — saving the place without it."),
              ),
            );
          }
        }
      }

      final place = PlaceEntity(
        id: '', // Firestore assigns the id via addPlace()'s collection.add().
        name: _nameCtrl.text.trim(),
        category: _selectedCategory,
        latitude: location.latitude,
        longitude: location.longitude,
        geohash: geohash,
        // Address is optional now; PlaceEntity.address is non-nullable, so
        // "not given" is the empty string — the same shape an Overpass import
        // already produces for a node with no addr:* tags, which
        // place_detail_screen already renders as "no address".
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        hours: _hoursCtrl.text.trim().isEmpty ? null : _hoursCtrl.text.trim(),
        photoUrls: photoUrls,
        createdBy: uid,
        createdAt: DateTime.now(),
      );

      await PlaceRepository().addPlace(place);

      // Pop with a result rather than invalidating here: this screen is
      // pushed on top of PlacesListScreen (same Navigator), and
      // nearbyPlacesProvider drives PlacesListScreen.build's
      // placesAsync.when directly — invalidating it swaps that screen's
      // list for a loading spinner. A same-tick "pop, then invalidate"
      // reorder isn't a strong enough guarantee against Flutter's
      // "'_dependents.isEmpty': is not true" InheritedElement assertion
      // (forum_thread_screen.dart hit the identical crash again even after
      // that reorder — Navigator.pop schedules route removal, it doesn't
      // complete it synchronously, so both tree mutations can still land in
      // the same frame). Returning a result here and having the caller
      // invalidate only after context.push's OWN future resolves (i.e.
      // after this route's entire removal, including its exit transition,
      // has actually finished — see PlacesListScreen) is a materially
      // stronger guarantee than the same-tick reorder, applied
      // preemptively here since this screen has the identical shape —
      // not yet confirmed against a live repro the way the forum crash was.
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add place: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The optional-photo control: an empty "add one" tile, or a preview with a
  /// remove button once something is chosen. Never blocks submission.
  Widget _buildPhotoPicker() {
    if (_photoPath == null) {
      return InkWell(
        onTap: _submitting ? null : _pickPhoto,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 22, color: AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(
                'Add a photo (optional)',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'A shopfront picture makes this place easy to spot',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Stack(
        children: [
          Image.file(
            File(_photoPath!),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            // A picked file can vanish (cache eviction, revoked permission)
            // between selection and build — fall back rather than throwing
            // an exception box into the middle of the form.
            errorBuilder: (_, __, ___) => Container(
              height: 160,
              color: AppColors.surface,
              alignment: Alignment.center,
              child: Text("Couldn't load that photo",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _photoAction(
                  icon: Icons.edit,
                  tooltip: 'Replace photo',
                  onTap: _submitting ? null : _pickPhoto,
                ),
                const SizedBox(width: 8),
                _photoAction(
                  icon: Icons.close,
                  tooltip: 'Remove photo',
                  onTap: _submitting ? null : () => setState(() => _photoPath = null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
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
              Text('Location', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
              Text('Category', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                        color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
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
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Rahman Motors'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
                minLines: 1,
                // No validator: the pin already says exactly where this is.
                // An address here is a convenience for the next rider, not a
                // requirement — demanding one just made people type junk.
                decoration: InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'e.g. Beside Omuk School, Mirpur 10',
                  helperMaxLines: 3,
                  helperText: 'Write it the way you\'d tell a friend — landmarks, '
                      'not a formal street address. "Beside Omuk School" or '
                      '"just after the Mirpur 10 circle" helps far more here.',
                  helperStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _lookingUpAddress ? null : _fillAddressFromPin,
                  icon: _lookingUpAddress
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(
                    _lookingUpAddress ? 'Looking up…' : "Use the pin's area",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _buildPhotoPicker(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Phone (optional)', hintText: '+880...'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hoursCtrl,
                style: TextStyle(color: AppColors.textPrimary),
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
