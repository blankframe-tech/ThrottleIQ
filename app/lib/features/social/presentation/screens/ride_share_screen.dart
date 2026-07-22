import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../data/repositories/ride_share_repository.dart';

const _audienceOptions = [
  ('public', 'Public', 'Anyone on ThrottleIQ'),
  ('followers', 'Followers', 'People who follow you'),
  ('mutual', 'Mutual', 'Riders you follow each other'),
];

/// End-of-ride share step: optional photo + audience tier, reached from
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
  String? _imagePath;
  String _audience = 'public';
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadPolyline();
  }

  Future<void> _loadPolyline() async {
    final dao = RidePointDao();
    final points = await dao.getForRide(widget.rideId);
    if (!mounted) return;
    setState(() {
      _polyline = points.map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile != null) setState(() => _imagePath = xfile.path);
  }

  Future<void> _share() async {
    final user = ref.read(currentUserProvider);
    final rideAsync = ref.read(rideDetailProvider(widget.rideId));
    final ride = rideAsync.valueOrNull;
    if (user == null || ride == null) return;

    setState(() => _sharing = true);
    try {
      final bikes = ref.read(garageProvider).valueOrNull ?? [];
      final bike = bikes.where((b) => b.id == ride.bikeId).firstOrNull;
      final repo = RideShareRepository();

      String? photoUrl;
      if (_imagePath != null) {
        photoUrl = await repo.uploadRidePhoto(user.uid, widget.rideId, File(_imagePath!));
      }

      await repo.shareRide(
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
        mapSnapshotUrl: null,
        audience: _audience,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride shared')),
      );
      context.go('/home/social');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share ride: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
            const EditorialLabel('Photo (optional)'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: AppColors.border),
                  image: _imagePath != null
                      ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
                      : null,
                ),
                child: _imagePath == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: AppColors.textTertiary, size: 32),
                            SizedBox(height: 8),
                            Text('Add a ride or bike photo',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              onPressed: () => setState(() => _imagePath = null),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
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
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
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
