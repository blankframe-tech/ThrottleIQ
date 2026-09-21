import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/full_screen_route_map_screen.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/riding_score_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../data/repositories/route_repository.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../providers/ride_feed_provider.dart';
import '../../../../shared/widgets/app_tile_layer.dart';
import '../../../../core/i18n/l10n_context.dart';

class SharedRideDetailScreen extends ConsumerStatefulWidget {
  final String rideId;
  final SharedRideEntity? initialRide;

  const SharedRideDetailScreen({
    super.key,
    required this.rideId,
    this.initialRide,
  });

  @override
  ConsumerState<SharedRideDetailScreen> createState() => _SharedRideDetailScreenState();
}

class _SharedRideDetailScreenState extends ConsumerState<SharedRideDetailScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _commentController = TextEditingController();
  List<RideCommentEntity>? _comments;
  bool _loadingComments = false;
  bool _savingRoute = false;
  int? _localVote;
  int _localUpvotes = 0;
  int _localDownvotes = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialRide != null) {
      _localVote = widget.initialRide!.myVote;
      _localUpvotes = widget.initialRide!.upvotes;
      _localDownvotes = widget.initialRide!.downvotes;
    }
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(1.0, 18.0));
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(1.0, 18.0));
    } catch (_) {}
  }

  void _openFullScreenMap(List<LatLng> polyline, SharedRideEntity ride) {
    if (polyline.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => FullScreenRouteMapScreen(
          polyline: polyline,
          title: ride.bikeName,
          subtitle: '${ride.userName} · ${ride.distanceKm.toStringAsFixed(1)} km',
          distanceKm: ride.distanceKm,
          durationSeconds: ride.durationSeconds,
          maxSpeedKmh: ride.maxSpeedKmh,
          avgSpeedKmh: ride.avgSpeedKmh,
          onSaveRoute: (ctx) async {
            final name = '${ride.userName}\'s ${ride.bikeName} Route';
            await RouteRepository().saveRoute(
              userId: ride.userId,
              name: name,
              polyline: polyline,
              distanceKm: ride.distanceKm,
            );
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(ctx.l10n.routeSavedMyRoutes)),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await RideShareRepository().getComments(widget.rideId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _commentController.clear();
    try {
      await RideShareRepository().addComment(
        rideId: widget.rideId,
        userId: user.uid,
        userName: user.displayName ?? 'Rider',
        userPhotoUrl: user.photoURL ?? '',
        text: text,
      );
      ref.read(rideFeedNotifierProvider.notifier).incrementCommentCount(widget.rideId);
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedPostComment(e))),
      );
    }
  }

  Future<void> _handleVote(int value) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final prevVote = _localVote;
    final prevUp = _localUpvotes;
    final prevDown = _localDownvotes;

    setState(() {
      if (_localVote == value) {
        // Toggle off
        _localVote = null;
        if (value == 1) _localUpvotes = (_localUpvotes - 1).clamp(0, 999999);
        if (value == -1) _localDownvotes = (_localDownvotes - 1).clamp(0, 999999);
      } else {
        if (_localVote == 1) _localUpvotes = (_localUpvotes - 1).clamp(0, 999999);
        if (_localVote == -1) _localDownvotes = (_localDownvotes - 1).clamp(0, 999999);
        _localVote = value;
        if (value == 1) _localUpvotes++;
        if (value == -1) _localDownvotes++;
      }
    });

    try {
      await ref.read(rideFeedNotifierProvider.notifier).vote(widget.rideId, value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localVote = prevVote;
        _localUpvotes = prevUp;
        _localDownvotes = prevDown;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.voteFailed(e))));
    }
  }

  Future<void> _saveAsRoute(SharedRideEntity ride) async {
    final user = ref.read(currentUserProvider);
    if (user == null || ride.polyline.isEmpty) return;

    setState(() => _savingRoute = true);
    try {
      final name = '${ride.userName}\'s ${ride.bikeName} Ride';
      await RouteRepository().saveRoute(
        userId: user.uid,
        name: name,
        polyline: ride.polyline,
        distanceKm: ride.distanceKm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.routeSavedMyRoutes)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotSaveRoute(e))),
      );
    } finally {
      if (mounted) setState(() => _savingRoute = false);
    }
  }

  void _recenterMap(List<LatLng> polyline) {
    if (polyline.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: polyline,
        padding: const EdgeInsets.all(32),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveRideAsync = ref.watch(sharedRideProvider(widget.rideId));
    final ride = liveRideAsync.valueOrNull ?? widget.initialRide;

    if (ride == null && liveRideAsync.isLoading) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(title: Text(context.l10n.rideDetails)),
        body: Center(child: CircularProgressIndicator(color: context.palette.primary)),
      );
    }

    if (ride == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(title: Text(context.l10n.rideDetails)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.palette.textTertiary),
              const SizedBox(height: 12),
              Text(context.l10n.rideNotFoundRemoved, style: TextStyle(color: context.palette.textSecondary)),
            ],
          ),
        ),
      );
    }

    // Sync initial upvotes if uninitialized
    if (_localVote == null && ride.myVote != null) {
      _localVote = ride.myVote;
      _localUpvotes = ride.upvotes;
      _localDownvotes = ride.downvotes;
    }

    final polyline = ride.polyline;
    final netScore = _localUpvotes - _localDownvotes;

    // Calculate pace
    final paceFormatted = (ride.distanceKm > 0 && ride.durationSeconds > 0)
        ? () {
            final totalPaceSeconds = (ride.durationSeconds / ride.distanceKm).round();
            final paceMin = totalPaceSeconds ~/ 60;
            final paceSec = totalPaceSeconds % 60;
            return "$paceMin'${paceSec.toString().padLeft(2, '0')}\" /km";
          }()
        : '--';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(ride.bikeName, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.palette.textPrimary),
            onSelected: (val) {
              if (val == 'report') {
                ReportBottomSheet.show(
                  context,
                  reportedId: ride.userId,
                  contentType: 'ride',
                  contentId: ride.id,
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'report', child: Text(context.l10n.reportRide)),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Interactive Route Map
            _buildInteractiveMap(polyline, ride),

            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Rider & Bike Info Card
                  _buildRiderCard(ride),
                  const SizedBox(height: 16),

                  // 3. Optional Rider Caption
                  if ((ride.caption ?? '').trim().isNotEmpty) ...[
                    _buildCaptionCard(ride.caption!.trim()),
                    const SizedBox(height: 16),
                  ],

                  // 4. Detailed Speed & Telemetry Stats
                  _buildTelemetrySection(ride, paceFormatted),
                  const SizedBox(height: 16),

                  // 5. Photos Gallery
                  if (ride.photoUrls.isNotEmpty) ...[
                    _buildPhotosGallery(ride.photoUrls),
                    const SizedBox(height: 16),
                  ],

                  // 6. Upvote / Downvote Bar
                  _buildVoteBar(netScore),
                  const SizedBox(height: 20),

                  // 7. Comments Section
                  _buildCommentsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveMap(List<LatLng> polyline, SharedRideEntity ride) {
    return Container(
      height: 310,
      width: double.infinity,
      color: context.palette.surface,
      child: Stack(
        children: [
          if (polyline.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: context.palette.textTertiary),
                  const SizedBox(height: 8),
                  Text(context.l10n.noGpsTrackAvailable,
                      style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
                ],
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: polyline.first,
                initialZoom: 13,
                initialCameraFit: CameraFit.coordinates(
                  coordinates: polyline,
                  padding: const EdgeInsets.all(36),
                  maxZoom: 16,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (_, __) => _openFullScreenMap(polyline, ride),
              ),
              children: [
                const AppTileLayer(),
                if (polyline.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polyline,
                        color: context.palette.primary,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: polyline.first,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.palette.success,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    if (polyline.length > 1)
                      Marker(
                        point: polyline.last,
                        width: 16,
                        height: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.palette.danger,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

          // Tap map to expand hint pill
          if (polyline.isNotEmpty)
            Positioned(
              left: 12,
              top: 12,
              child: GestureDetector(
                onTap: () => _openFullScreenMap(polyline, ride),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.palette.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(context.shape.radiusFull),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full, size: 14, color: context.palette.primary),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.mapExpandHintLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Map action controls overlay
          if (polyline.isNotEmpty)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in_shared_map',
                    key: const Key('map_zoom_in_button'),
                    backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                    foregroundColor: context.palette.textPrimary,
                    tooltip: context.l10n.zoomIn,
                    onPressed: _zoomIn,
                    child: const Icon(Icons.add, size: 20),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out_shared_map',
                    key: const Key('map_zoom_out_button'),
                    backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                    foregroundColor: context.palette.textPrimary,
                    tooltip: context.l10n.zoomOut,
                    onPressed: _zoomOut,
                    child: const Icon(Icons.remove, size: 20),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'recenter_shared_map',
                    key: const Key('map_recenter_button'),
                    backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                    foregroundColor: context.palette.textPrimary,
                    tooltip: context.l10n.recenterRoute,
                    onPressed: () => _recenterMap(polyline),
                    child: const Icon(Icons.my_location, size: 18),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'fullscreen_shared_map',
                    key: const Key('map_fullscreen_button'),
                    backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                    foregroundColor: context.palette.textPrimary,
                    tooltip: context.l10n.fullscreenMap,
                    onPressed: () => _openFullScreenMap(polyline, ride),
                    child: const Icon(Icons.fullscreen, size: 20),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'save_shared_route',
                    key: const Key('map_save_route_button'),
                    backgroundColor: context.palette.primary,
                    foregroundColor: Colors.white,
                    tooltip: context.l10n.saveAsRouteAction,
                    onPressed: _savingRoute ? null : () => _saveAsRoute(ride),
                    child: _savingRoute
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.bookmark_add_outlined, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiderCard(SharedRideEntity ride) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${ride.userId}'),
            child: UserAvatar(photoUrl: ride.userPhotoUrl, name: ride.userName, radius: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile/${ride.userId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.userName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ride.bikeName} · ${ride.bikeType}',
                    style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              EditorialPill(
                ride.audience.toUpperCase(),
                tone: PillTone.neutral,
                filled: false,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().format(ride.rideDate),
                style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionCard(String caption) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: context.palette.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caption,
              style: TextStyle(fontSize: 14, color: context.palette.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetrySection(SharedRideEntity ride, String paceFormatted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialLabel(context.l10n.speedPerformanceDetails),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: context.l10n.maxSpeed,
                value: ride.maxSpeedKmh.toStringAsFixed(1),
                unit: 'km/h',
                icon: Icons.speed,
                accentColor: context.palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: context.l10n.avgSpeed,
                value: ride.avgSpeedKmh.toStringAsFixed(1),
                unit: 'km/h',
                icon: Icons.trending_up,
                accentColor: context.palette.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: context.l10n.distanceLabel,
                value: ride.distanceKm.toStringAsFixed(1),
                unit: 'km',
                icon: Icons.straighten,
                accentColor: context.palette.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: context.l10n.duration,
                value: SpeedFormatter.durationFromSeconds(ride.durationSeconds),
                unit: '',
                icon: Icons.timer_outlined,
                accentColor: context.palette.success,
              ),
            ),
          ],
        ),
        if (ride.ridingScore != null) ...[
          const SizedBox(height: 12),
          RidingScoreBadge(score: ride.ridingScore!),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(context.shape.radiusMd),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.two_wheeler, size: 20, color: context.palette.primary),
              const SizedBox(width: 12),
              Text(context.l10n.ridingPace, style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(paceFormatted, style: TextStyle(fontWeight: FontWeight.bold, color: context.palette.textPrimary, fontSize: 14)),
            ],
          ),
        ),
        if (ride.polyline.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRouteInfoCard(ride),
        ],
      ],
    );
  }

  Widget _buildRouteInfoCard(SharedRideEntity ride) {
    if (ride.polyline.isEmpty) return const SizedBox.shrink();
    final start = ride.polyline.first;
    final end = ride.polyline.last;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 20, color: context.palette.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.routeGpsDetailsLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.trackPoints(ride.polyline.length),
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(context.l10n.startColon, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: context.palette.textPrimary)),
              Text(
                '${start.latitude.toStringAsFixed(4)}°, ${start.longitude.toStringAsFixed(4)}°',
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
            ],
          ),
          if (ride.polyline.length > 1) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.palette.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Text(context.l10n.finishColon, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: context.palette.textPrimary)),
                Text(
                  '${end.latitude.toStringAsFixed(4)}°, ${end.longitude.toStringAsFixed(4)}°',
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('explore_full_route_button'),
              onPressed: () => _openFullScreenMap(ride.polyline, ride),
              icon: const Icon(Icons.fullscreen, size: 18),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.l10n.exploreFullRouteAction,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosGallery(List<String> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialLabel(context.l10n.ridePhotos),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final url = photos[index];
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(ctx.shape.radiusLg),
                        child: Image.network(url, fit: BoxFit.contain),
                      ),
                    ),
                  );
                },
                child: Container(
                  // Painted over the photo, matching the feed collage.
                  foregroundDecoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(context.shape.radiusMd),
                    border: Border.all(
                      color: context.palette.border,
                      width: context.shape.outlineWidth,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.shape.radiusMd),
                    child: Image.network(
                      url,
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 130,
                        height: 130,
                        color: context.palette.surface,
                        child: Icon(Icons.broken_image, color: context.palette.textTertiary),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVoteBar(int netScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.upvote,
            icon: Icon(
              Icons.arrow_upward,
              color: _localVote == 1 ? context.palette.primary : context.palette.textSecondary,
              size: 22,
            ),
            onPressed: () => _handleVote(1),
          ),
          Text(
            '$netScore',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.palette.textPrimary),
          ),
          IconButton(
            tooltip: context.l10n.downvote,
            icon: Icon(
              Icons.arrow_downward,
              color: _localVote == -1 ? context.palette.danger : context.palette.textSecondary,
              size: 22,
            ),
            onPressed: () => _handleVote(-1),
          ),
          const Spacer(),
          Icon(Icons.chat_bubble_outline, size: 20, color: context.palette.textSecondary),
          const SizedBox(width: 8),
          Text(context.l10n.commentsCount(_comments?.length ?? 0), style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialLabel(context.l10n.commentsLabel),
        const SizedBox(height: 10),

        if (_loadingComments)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_comments == null || _comments!.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.noCommentsYetBe,
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments!.length,
            separatorBuilder: (_, __) => Divider(color: context.palette.border, height: 16),
            itemBuilder: (context, index) {
              final comment = _comments![index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(photoUrl: comment.userPhotoUrl, name: comment.userName, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(comment.userName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, color: context.palette.textPrimary, fontSize: 13)),
                            const Spacer(),
                            Text(DateFormat.MMMd().format(comment.createdAt),
                                style: TextStyle(color: context.palette.textTertiary, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(comment.text,
                            style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: context.l10n.addComment,
                  hintStyle: TextStyle(color: context.palette.textTertiary, fontSize: 14),
                  filled: true,
                  fillColor: context.palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.shape.radiusFull),
                    borderSide: BorderSide(color: context.palette.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.l10n.send,
              icon: Icon(Icons.send, color: context.palette.primary),
              onPressed: _submitComment,
            ),
          ],
        ),
      ],
    );
  }
}

