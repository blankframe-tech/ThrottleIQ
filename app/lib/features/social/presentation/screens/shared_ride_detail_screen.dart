import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../moderation/presentation/widgets/report_bottom_sheet.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../data/repositories/route_repository.dart';
import '../../domain/entities/ride_comment_entity.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../providers/ride_feed_provider.dart';

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
    super.dispose();
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
        SnackBar(content: Text('Failed to post comment: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
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
        const SnackBar(content: Text('Route saved to My Routes!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save route: $e')),
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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Ride Details')),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (ride == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Ride Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Ride not found or removed', style: TextStyle(color: AppColors.textSecondary)),
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
            return "${paceMin}'${paceSec.toString().padLeft(2, '0')}\" /km";
          }()
        : '--';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ride.bikeName, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
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
              const PopupMenuItem(value: 'report', child: Text('Report Ride')),
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
      height: 280,
      width: double.infinity,
      color: AppColors.surface,
      child: Stack(
        children: [
          if (polyline.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 8),
                  Text('No GPS track available for this ride',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bft.throttleiq',
                ),
                if (polyline.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polyline,
                        color: AppColors.primary,
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
                          color: AppColors.success,
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
                            color: AppColors.danger,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
                    heroTag: 'recenter_shared_map',
                    backgroundColor: AppColors.surface.withValues(alpha: 0.9),
                    foregroundColor: AppColors.textPrimary,
                    onPressed: () => _recenterMap(polyline),
                    child: const Icon(Icons.my_location, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'save_shared_route',
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    tooltip: 'Save as Route',
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ride.bikeName} · ${ride.bikeType}',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caption,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
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
        const EditorialLabel('Speed & Performance Details'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Max Speed',
                value: '${ride.maxSpeedKmh.toStringAsFixed(1)}',
                unit: 'km/h',
                icon: Icons.speed,
                accentColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Avg Speed',
                value: '${ride.avgSpeedKmh.toStringAsFixed(1)}',
                unit: 'km/h',
                icon: Icons.trending_up,
                accentColor: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Distance',
                value: '${ride.distanceKm.toStringAsFixed(1)}',
                unit: 'km',
                icon: Icons.straighten,
                accentColor: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Duration',
                value: SpeedFormatter.durationFromSeconds(ride.durationSeconds),
                unit: '',
                icon: Icons.timer_outlined,
                accentColor: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_bike, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Average Pace', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(paceFormatted, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosGallery(List<String> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialLabel('Ride Photos'),
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
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        child: Image.network(url, fit: BoxFit.contain),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Image.network(
                    url,
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 130,
                      height: 130,
                      color: AppColors.surface,
                      child: Icon(Icons.broken_image, color: AppColors.textTertiary),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_upward,
              color: _localVote == 1 ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => _handleVote(1),
          ),
          Text(
            '$netScore',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_downward,
              color: _localVote == -1 ? AppColors.danger : AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => _handleVote(-1),
          ),
          const Spacer(),
          Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('${_comments?.length ?? 0} comments', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialLabel('Comments'),
        const SizedBox(height: 10),

        if (_loadingComments)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_comments == null || _comments!.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No comments yet. Be the first to comment!',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments!.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 16),
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
                                    fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
                            const Spacer(),
                            Text(DateFormat.MMMd().format(comment.createdAt),
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(comment.text,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.send, color: AppColors.primary),
              onPressed: _submitComment,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
