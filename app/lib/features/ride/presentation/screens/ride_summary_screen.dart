import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/cloud/export_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../core/utils/riding_score.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../social/data/repositories/ride_share_repository.dart';
import '../../domain/entities/ride_entity.dart';
import '../providers/ride_recording_provider.dart';
import '../../../../core/database/daos/ride_point_dao.dart';

class RideSummaryScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideSummaryScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends ConsumerState<RideSummaryScreen> {
  List<LatLng> _polyline = [];
  bool _polylineLoaded = false;
  bool _sharing = false;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    _loadPolyline();
  }

  Future<void> _loadPolyline() async {
    final dao = RidePointDao();
    final points = await dao.getForRide(widget.rideId);
    setState(() {
      _polyline = points
          .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
          .toList();
      _polylineLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(rideDetailProvider(widget.rideId));
    final name = ref.watch(currentUserProvider)?.displayName?.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home/record'),
        ),
      ),
      body: rideAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (ride) {
          if (ride == null) {
            return const Center(
                child: Text('Ride not found',
                    style: TextStyle(color: AppColors.textSecondary)));
          }

          final startCenter = _polyline.isNotEmpty
              ? _polyline.first
              : const LatLng(23.8103, 90.4125);
          final score = computeRidingScore(
            hardBrakes: ride.hardBrakeCount,
            rapidAccel: ride.rapidAccelCount,
            highJerk: ride.highJerkCount,
          );
          final scoreColor = score >= 80
              ? AppColors.success
              : score >= 60
                  ? AppColors.attention
                  : AppColors.danger;
          final scoreLabel = score >= 80
              ? 'Smooth op.'
              : score >= 60
                  ? 'Steady'
                  : 'Aggressive';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 0,
                AppDimensions.paddingMd, AppDimensions.paddingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Black "nice ride" header ─────────────────────────────
                InkPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name != null ? 'Nice ride, $name!' : 'Nice ride!',
                          style: display(24, color: AppColors.onInk)),
                      const SizedBox(height: 4),
                      Text(_formatDate(ride.startTime),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.onInkMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 4-stat row ───────────────────────────────────────────
                EditorialCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCell(
                          value: ride.distanceKm.toStringAsFixed(1),
                          label: 'km',
                          align: CrossAxisAlignment.center,
                          valueSize: 20,
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        child: StatCell(
                          value: SpeedFormatter.durationFromSeconds(
                              ride.durationSeconds ?? 0),
                          label: 'moving',
                          align: CrossAxisAlignment.center,
                          valueSize: 20,
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        child: StatCell(
                          value: ride.avgSpeedKmh.toStringAsFixed(0),
                          label: 'avg',
                          align: CrossAxisAlignment.center,
                          valueSize: 20,
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        child: StatCell(
                          value: ride.maxSpeedKmh.toStringAsFixed(0),
                          label: 'max',
                          align: CrossAxisAlignment.center,
                          valueSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Score tile + rating ──────────────────────────────────
                IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$score',
                              style: display(34, color: AppColors.onInk)),
                          Text(scoreLabel.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.onInkMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EditorialCard(
                        padding: const EdgeInsets.all(AppDimensions.paddingMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const EditorialLabel('Riding score'),
                            const SizedBox(height: 6),
                            Text(scoreLabel,
                                style: display(18, letterSpacing: 0, color: scoreColor)),
                            const SizedBox(height: 2),
                            const Text('out of 100',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ),
                const SizedBox(height: 12),

                // ── Events ───────────────────────────────────────────────
                EditorialCard(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCell(
                          value: '${ride.hardBrakeCount}',
                          label: 'hard brakes',
                          align: CrossAxisAlignment.center,
                          valueColor:
                              ride.hardBrakeCount > 0 ? AppColors.danger : null,
                          valueSize: 20,
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        child: StatCell(
                          value: '${ride.rapidAccelCount}',
                          label: 'rapid accel',
                          align: CrossAxisAlignment.center,
                          valueColor: ride.rapidAccelCount > 0
                              ? AppColors.attention
                              : null,
                          valueSize: 20,
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        child: StatCell(
                          value: '${ride.highJerkCount}',
                          label: 'high jerk',
                          align: CrossAxisAlignment.center,
                          valueColor:
                              ride.highJerkCount > 0 ? AppColors.attention : null,
                          valueSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Map ──────────────────────────────────────────────────
                const EditorialLabel('Route'),
                const SizedBox(height: 10),
                _buildMap(ride, startCenter),
                const SizedBox(height: 20),

                // ── Actions ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/home/record'),
                        child: const Text('Save & done'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_sharing || _shared || !_polylineLoaded)
                            ? null
                            : () => _shareRide(ride),
                        icon: _sharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.textPrimary),
                              )
                            : Icon(_shared ? Icons.check_circle : Icons.public,
                                size: 18),
                        label: Text(_shared ? 'Shared' : 'Share'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _exportRide(ride, gpx: false),
                        icon: const Icon(Icons.data_object, size: 18),
                        label: const Text('Export JSON'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _exportRide(ride, gpx: true),
                        icon: const Icon(Icons.route, size: 18),
                        label: const Text('Export GPX'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 34, color: AppColors.border);

  Widget _buildMap(RideEntity ride, LatLng startCenter) {
    if (ride.mapSnapshotPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Image.file(File(ride.mapSnapshotPath!),
            height: 200, width: double.infinity, fit: BoxFit.cover),
      );
    }
    if (!_polylineLoaded) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: startCenter,
            initialZoom: _polyline.length > 1 ? 13 : 15,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bft.throttleiq',
            ),
            if (_polyline.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                      points: _polyline, color: AppColors.primary, strokeWidth: 4),
                ],
              ),
            if (_polyline.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _polyline.first,
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
                  if (_polyline.length > 1)
                    Marker(
                      point: _polyline.last,
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
      ),
    );
  }

  Future<void> _exportRide(RideEntity ride, {required bool gpx}) async {
    final service = ExportService();
    final rideMap = {
      'id': ride.id,
      'startTime': ride.startTime.toIso8601String(),
      'endTime': ride.endTime?.toIso8601String(),
      'distanceM': ride.distanceM,
      'avgSpeedMs': ride.avgSpeedMs,
      'maxSpeedMs': ride.maxSpeedMs,
      'durationSeconds': ride.durationSeconds,
      'hardBrakeCount': ride.hardBrakeCount,
      'rapidAccelCount': ride.rapidAccelCount,
      'highJerkCount': ride.highJerkCount,
    };
    final file = gpx
        ? await service.exportRideToGPX(rideMap)
        : await service.exportRideToJSON(rideMap);
    if (!mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
      return;
    }
    await Share.shareXFiles([XFile(file.path)], subject: 'ThrottleIQ ride export');
  }

  Future<void> _shareRide(RideEntity ride) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sharing = true);
    try {
      final bikes = ref.read(garageProvider).valueOrNull ?? [];
      final bike = bikes.where((b) => b.id == ride.bikeId).firstOrNull;

      await RideShareRepository().shareRide(
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
        isPrivate: false,
        allowedUserIds: const [],
      );
      if (!mounted) return;
      setState(() => _shared = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride shared to the public feed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share ride: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
