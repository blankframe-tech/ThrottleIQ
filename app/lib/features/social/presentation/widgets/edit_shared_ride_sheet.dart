import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/shared_ride_entity.dart';

const _captionMaxLength = 280;

/// Owner edit of a shared post: caption and photos, nothing else. Pops `true`
/// once saved so the caller can refresh.
class EditSharedRideSheet extends StatefulWidget {
  final SharedRideEntity ride;

  const EditSharedRideSheet({super.key, required this.ride});

  static Future<bool?> show(BuildContext context, SharedRideEntity ride) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.palette.background,
        builder: (_) => EditSharedRideSheet(ride: ride),
      );

  @override
  State<EditSharedRideSheet> createState() => _EditSharedRideSheetState();
}

class _EditSharedRideSheetState extends State<EditSharedRideSheet> {
  late final _caption = TextEditingController(text: widget.ride.caption ?? '');
  // Existing photos are https URLs, newly picked ones are local file paths;
  // new ones upload on save.
  late final List<String> _photos = [...widget.ride.photoUrls];
  bool _saving = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool _isRemote(String p) => p.startsWith('http');

  Future<void> _pick() async {
    final remaining = kMaxRidePhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker()
        .pickMultiImage(imageQuality: 80, limit: remaining);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(remaining).map((x) => x.path)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = RideShareRepository();
      final urls = <String>[
        for (final p in _photos)
          _isRemote(p)
              ? p
              : await repo.uploadRidePhoto(
                  widget.ride.userId, widget.ride.id, File(p)),
      ];
      await repo.updateSharedRideContent(widget.ride.id,
          caption: _caption.text, photoUrls: urls);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.couldNotSaveChanges(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    const tile = 96.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMd,
        AppDimensions.paddingMd,
        AppDimensions.paddingMd,
        AppDimensions.paddingMd + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.editRide,
                style: display(context, 20, letterSpacing: 0)),
            const SizedBox(height: 16),
            EditorialLabel(context.l10n.captionLabel),
            const SizedBox(height: 10),
            TextField(
              controller: _caption,
              maxLines: 3,
              maxLength: _captionMaxLength,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: context.l10n.saySomethingAboutThis,
                hintStyle:
                    TextStyle(color: context.palette.textTertiary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: tile,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: tile,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  context.shape.radiusXl),
                              child: _isRemote(_photos[i])
                                  ? Image.network(_photos[i], fit: BoxFit.cover)
                                  : Image.file(File(_photos[i]),
                                      fit: BoxFit.cover),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _photos.removeAt(i)),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_photos.length < kMaxRidePhotos)
                    GestureDetector(
                      onTap: _pick,
                      child: Container(
                        width: tile,
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          borderRadius:
                              BorderRadius.circular(context.shape.radiusXl),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined,
                            color: context.palette.textTertiary, size: 26),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }
}
