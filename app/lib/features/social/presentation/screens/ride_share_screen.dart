import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/cloud/outbox_service.dart';
import '../../../../core/cloud/ride_track_loader.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/analytics/analytics_service.dart';

const _captionMaxLength = 280;

/// (value stored on the post, label, description). The value is what is
/// written to Firestore and matched by the rules, so it never changes with the
/// rider's language; only the label and description shown here do.
List<(String, String, String)> _audienceOptions(AppLocalizations l10n) => [
      ('public', l10n.audiencePublic, l10n.anyoneThrottleiq),
      ('followers', l10n.audienceFollowers, l10n.peopleWhoFollow),
      ('mutual', l10n.audienceMutual, l10n.ridersFollowEachOther),
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
    final points = await RideTrackLoader.load(widget.rideId);
    if (!mounted) return;
    setState(() {
      _polyline = points
          .map((p) => LatLng(
              (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
          .toList();
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
          context.l10n.canAddUpPhotos(kMaxRidePhotos));
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80, limit: remaining);
    if (picked.isEmpty || !mounted) return;

    final accepted = picked.take(remaining).map((x) => x.path).toList();
    setState(() => _imagePaths.addAll(accepted));

    if (picked.length > remaining) {
      _showCapMessage(
          context.l10n.onlyPhotosPerRide(kMaxRidePhotos, remaining));
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
      // allBikesProvider: a ride on an archived bike still names its bike.
      final bikes = await ref.read(allBikesProvider.future);
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
        hardBrakeCount: ride.hardBrakeCount,
        rapidAccelCount: ride.rapidAccelCount,
        highJerkCount: ride.highJerkCount,
      );

      // Counted at the rider's intent (queued), not delivery: a share made offline is still a share.
      AnalyticsService.instance.log(AnalyticsEvent.rideShared);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deliveredNow
              ? context.l10n.rideShared
              : context.l10n.savedWellPostIt),
        ),
      );
      context.go('/home/social');
    } catch (e) {
      // Reaching here now means something local failed (the queue write
      // itself), not a network problem — those are absorbed by the outbox.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedShareRide(e))),
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
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(context.shape.radiusXl),
            border: Border.all(color: context.palette.border),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, color: context.palette.textTertiary, size: 32),
                const SizedBox(height: 8),
                Text(context.l10n.addUpRideBike(kMaxRidePhotos),
                    style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
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
                    borderRadius: BorderRadius.circular(context.shape.radiusXl),
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
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(context.shape.radiusXl),
                  border: Border.all(color: context.palette.border),
                ),
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: context.palette.textTertiary, size: 26),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(context.l10n.shareRide),
        leading: IconButton(
          tooltip: context.l10n.close,
          icon: const Icon(Icons.close),
          // Pop when there's somewhere to pop to; the "End ride + Share"
          // path arrives via context.go, so fall back to this ride's summary
          // rather than wiping the stack to the Record tab.
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/ride/summary/${widget.rideId}'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorialLabel(context.l10n.captionLabel),
            const SizedBox(height: 10),
            TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: _captionMaxLength,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: context.l10n.saySomethingAboutThis,
                hintStyle: TextStyle(color: context.palette.textTertiary, fontSize: 14),
                counterStyle: TextStyle(color: context.palette.textTertiary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                EditorialLabel(context.l10n.photosOptional),
                const Spacer(),
                Text('${_imagePaths.length}/$kMaxRidePhotos',
                    style: TextStyle(color: context.palette.textTertiary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            _buildPhotoPicker(),
            const SizedBox(height: 24),
            EditorialLabel(context.l10n.whoCanSeeThis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _audienceOptions(context.l10n))
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
              _audienceOptions(context.l10n).firstWhere((o) => o.$1 == _audience).$3,
              style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
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
              label: Text(context.l10n.saveAsRoute),
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
                  : Text(context.l10n.shareAction),
            ),
          ],
        ),
      ),
    );
  }
}
