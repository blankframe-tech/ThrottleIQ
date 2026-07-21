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
import '../../../../shared/widgets/stat_card.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ride Summary'),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Map preview ──────────────────────────────────────────
                if (ride.mapSnapshotPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: Image.file(File(ride.mapSnapshotPath!),
                        height: 200, width: double.infinity, fit: BoxFit.cover),
                  )
                else if (_polylineLoaded)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: startCenter,
                          initialZoom: _polyline.length > 1 ? 13 : 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.throttleiq.throttleiq',
                          ),
                          if (_polyline.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _polyline,
                                  color: AppColors.primary,
                                  strokeWidth: 4,
                                ),
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
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Date & title ─────────────────────────────────────────
                Text(
                  _formatDate(ride.startTime),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ride Complete',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),

                const SizedBox(height: 20),

                // ── Core stats grid ──────────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      label: 'Distance',
                      value: ride.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                      icon: Icons.route,
                      isPrimary: true,
                    ),
                    StatCard(
                      label: 'Duration',
                      value: SpeedFormatter.durationFromSeconds(
                          ride.durationSeconds ?? 0),
                      icon: Icons.timer_outlined,
                    ),
                    StatCard(
                      label: 'Avg Speed',
                      value: ride.avgSpeedKmh.toStringAsFixed(0),
                      unit: 'km/h',
                      icon: Icons.speed,
                      isPrimary: true,
                    ),
                    StatCard(
                      label: 'Max Speed',
                      value: ride.maxSpeedKmh.toStringAsFixed(0),
                      unit: 'km/h',
                      icon: Icons.rocket_launch_outlined,
                      valueColor:
                          ride.maxSpeedKmh > 100 ? AppColors.warning : null,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Riding events ────────────────────────────────────────
                const Text('Riding Events',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _EventCard(
                        icon: Icons.warning_amber,
                        color: AppColors.danger,
                        label: 'Hard Brakes',
                        count: ride.hardBrakeCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EventCard(
                        icon: Icons.bolt,
                        color: AppColors.secondary,
                        label: 'Rapid Accel',
                        count: ride.rapidAccelCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EventCard(
                        icon: Icons.vibration,
                        color: AppColors.warning,
                        label: 'High Jerk',
                        count: ride.highJerkCount,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Riding score ─────────────────────────────────────────
                _RidingScoreCard(
                  hardBrakes: ride.hardBrakeCount,
                  rapidAccel: ride.rapidAccelCount,
                  highJerk: ride.highJerkCount,
                ),

                const SizedBox(height: 20),

                // ── Export ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportRide(ride, gpx: false),
                        icon: const Icon(Icons.data_object, size: 18),
                        label: const Text('Export JSON'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportRide(ride, gpx: true),
                        icon: const Icon(Icons.route, size: 18),
                        label: const Text('Export GPX'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_sharing || _shared || !_polylineLoaded)
                        ? null
                        : () => _shareRide(ride),
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : Icon(_shared ? Icons.check_circle : Icons.public, size: 18),
                    label: Text(_shared ? 'Shared to Feed' : 'Share this ride'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home/record'),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportRide(RideEntity ride, {required bool gpx}) async {
    final service = ExportService();
    // Map keys match what ExportService/_generateGPX read.
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
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ThrottleIQ ride export',
    );
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

class _EventCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _EventCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _RidingScoreCard extends StatelessWidget {
  final int hardBrakes;
  final int rapidAccel;
  final int highJerk;

  const _RidingScoreCard({
    required this.hardBrakes,
    required this.rapidAccel,
    required this.highJerk,
  });

  @override
  Widget build(BuildContext context) {
    final score = computeRidingScore(
      hardBrakes: hardBrakes,
      rapidAccel: rapidAccel,
      highJerk: highJerk,
    );
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : AppColors.danger;
    final label =
        score >= 80 ? 'Smooth Rider' : score >= 60 ? 'Average' : 'Aggressive';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Riding Score',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -2),
          ),
          const Text('/100',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
