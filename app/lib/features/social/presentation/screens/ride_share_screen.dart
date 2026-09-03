import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../domain/entities/shared_ride_entity.dart';

const _captionMaxLength = 280;

const _audienceOptions = [
  ('public', 'Public', 'Anyone on ThrottleIQ'),
  ('followers', 'Followers', 'People who follow you'),
  ('mutual', 'Mutual', 'Riders you follow each other'),
];

/// End-of-ride share step: up to [kMaxRidePhotos] photos + audience tier,
/// reached from
/// [RideSummaryScreen]'s Share button. Re-derives the ride/polyline/bike
/// itself (rather than threading them through the router) the same way
/// RideSummaryScreen does.
class RideShareScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideShareScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideShareScreen> createState() => _RideShareScreenState();
}

class _RideShareScreenState extends ConsumerState<RideShareScreen> {
  List<LatLng> _polyline = [];

  /// Local file paths of the picked photos, in the order they'll appear on the
  /// feed card. Never longer than [kMaxRidePhotos] — see [_pickImages].
  final List<String> _imagePaths = [];

  String _audience = 'public';
  bool _sharing = false;
  final _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPolyline();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadPolyline() async {
    final dao = RidePointDao();
    final points = await dao.getForRide(widget.rideId);
    if (!mounted) return;
    setState(() {
      _polyline = points.map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList();
    });
  }

  /// Picks photos, keeping the total at or under [kMaxRidePhotos].
  ///
  /// The picker's own `limit` is only a hint (platforms are free to ignore
  /// it), so the cap is enforced again here and the rider is told plainly
  /// what was dropped rather than silently losing a photo they chose.
  Future<void> _pickImages() async {
    final remaining = kMaxRidePhotos - _imagePaths.length;
    if (remaining <= 0) {
      _showCapMessage(
          'You can add up to $kMaxRidePhotos photos. Remove one to add another.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80, limit: remaining);
    if (picked.isEmpty || !mounted) return;

    final accepted = picked.take(remaining).map((x) => x.path).toList();
    setState(() => _imagePaths.addAll(accepted));

    if (picked.length > remaining) {
      _showCapMessage(
          'Only $kMaxRidePhotos photos per ride — kept the first $remaining.');
    }
  }

  void _showCapMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    final user = ref.read(currentUserProvider);
    final rideAsync = ref.read(rideDetailProvider(widget.rideId));
    final ride = rideAsync.valueOrNull;
    if (user == null || ride == null) return;

    final caption = _captionController.text.trim();

    setState(() => _sharing = true);
    try {
      final bikes = ref.read(garageProvider).valueOrNull ?? [];
      final bike = bikes.where((b) => b.id == ride.bikeId).firstOrNull;

      // Handed to the outbox rather than written straight to Firestore. The
      // rider's intent is on disk before this returns, so a share started with
      // no signal is never lost and never hangs — it posts on the next sync.
      // Photo uploads are part of the queued operation (the local file paths
      // travel with it), which is why nothing is uploaded here first: an
      // upload that succeeded while the Firestore write didn't would otherwise
      // have to be redone, orphaning the first copy.
      final deliveredNow = await ref.read(outboxServiceProvider).enqueueShareRide(
        rideId: ride.id,
        userId: user.uid,
        userName: user.displayName ?? 'Rider',
        userPhotoUrl: user.photoURL ?? '',
        bikeId: ride.bikeId,
        bikeName: bike?.displayName ?? 'Unknown Bike',
        bikeType: bike?.cc != null ? '${bike!.cc}cc' : 'Motorcycle',
        rideDate: ride.startTime,
        distanceKm: ride.distanceKm,
        durationSeconds: ride.durationSeconds ?? 0,
        maxSpeedKmh: ride.maxSpeedKmh,
        polyline: _polyline,
        audience: _audience,
        localPhotoPaths: _imagePaths,
        caption: caption.isEmpty ? null : caption,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deliveredNow
              ? 'Ride shared'
              : "Saved — we'll post it when you're back online"),
        ),
      );
      context.go('/home/social');
    } catch (e) {
      // Reaching here now means something local failed (the queue write
      // itself), not a network problem — those are absorbed by the outbox.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share ride: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Empty state = one big "add photos" panel (the pre-multi-photo look).
  /// Once something is picked it becomes a thumbnail row with a remove button
  /// per photo and an add tile that disappears at the cap, so the limit is
  /// visible in the UI rather than only surfacing as an error.
  Widget _buildPhotoPicker() {
    if (_imagePaths.isEmpty) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, color: AppColors.textTertiary, size: 32),
                const SizedBox(height: 8),
                Text('Add up to $kMaxRidePhotos ride or bike photos',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    const tile = 104.0;
    // Scrolls rather than wraps: three tiles plus the add tile can exceed a
    // narrow phone's content width, and an overflow stripe in the share sheet
    // is worse than a nudge-to-scroll.
    return SizedBox(
      height: tile,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _imagePaths.length; i++) ...[
            SizedBox(
              width: tile,
              height: tile,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                    child: Image.file(File(_imagePaths[i]), fit: BoxFit.cover),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: GestureDetector(
                        onTap: () => setState(() => _imagePaths.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (_imagePaths.length < kMaxRidePhotos)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.textTertiary, size: 26),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Share ride'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home/record'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EditorialLabel('Caption'),
            const SizedBox(height: 10),
            TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: _captionMaxLength,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Say something about this ride',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                counterStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const EditorialLabel('Photos (optional)'),
                const Spacer(),
                Text('${_imagePaths.length}/$kMaxRidePhotos',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            _buildPhotoPicker(),
            const SizedBox(height: 24),
            const EditorialLabel('Who can see this'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _audienceOptions)
                  GestureDetector(
                    onTap: () => setState(() => _audience = option.$1),
                    child: EditorialPill(
                      option.$2,
                      filled: _audience == option.$1,
                      tone: _audience == option.$1 ? PillTone.accent : PillTone.neutral,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _audienceOptions.firstWhere((o) => o.$1 == _audience).$3,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            // "Add to routes" belongs here because saving a route is something
            // the rider decides right after a ride, while they're already
            // deciding what to do with it.
            OutlinedButton.icon(
              onPressed: _sharing
                  ? null
                  : () => context.push('/routes/save/${widget.rideId}'),
              icon: const Icon(Icons.route_outlined, size: 18),
              label: const Text('Save as route'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _sharing ? null : _share,
              child: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }
}
