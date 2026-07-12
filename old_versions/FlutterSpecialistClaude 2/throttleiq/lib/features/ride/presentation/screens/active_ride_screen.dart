import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../providers/ride_recording_provider.dart';
import '../../../ride/domain/calculators/event_detector.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  late AnimationController _alertCtrl;
  late Animation<Color?> _alertColor;
  RideAlert _lastAlert = RideAlert.none;

  @override
  void initState() {
    super.initState();
    _alertCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _alertColor = ColorTween(begin: Colors.transparent, end: Colors.transparent)
        .animate(_alertCtrl);
  }

  @override
  void dispose() {
    _alertCtrl.dispose();
    super.dispose();
  }

  void _triggerAlert(RideAlert alert) {
    if (alert == _lastAlert) return;
    _lastAlert = alert;

    Color flashColor;
    switch (alert) {
      case RideAlert.hardBraking:
        flashColor = AppColors.danger.withOpacity(0.4);
        break;
      case RideAlert.rapidAccel:
        flashColor = AppColors.orange.withOpacity(0.3);
        break;
      case RideAlert.overspeed:
        flashColor = AppColors.warning.withOpacity(0.3);
        break;
      case RideAlert.fatigue:
        flashColor = AppColors.primary.withOpacity(0.3);
        break;
      default:
        return;
    }

    _alertColor = ColorTween(begin: flashColor, end: Colors.transparent)
        .animate(CurvedAnimation(parent: _alertCtrl, curve: Curves.easeOut));
    _alertCtrl.forward(from: 0);
  }

  Future<void> _stopRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End Ride?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Your ride will be saved and synced.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Ride'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final rideId = await ref.read(rideRecordingProvider.notifier).stopRide();
    if (mounted) {
      if (rideId != null) {
        context.go('/ride/summary/$rideId');
      } else {
        context.go('/home/record');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideRecordingProvider);

    // Redirect if no active ride
    if (rideState.status == RecordingStatus.idle ||
        rideState.status == RecordingStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home/record'));
      return const SizedBox.shrink();
    }

    // Trigger alert animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAlert(rideState.activeAlert);
    });

    // Pan camera to latest position
    if (_mapCtrl != null && rideState.polyline.isNotEmpty) {
      final last = rideState.polyline.last;
      _mapCtrl!.animateCamera(CameraUpdate.newLatLng(last));
    }

    final isPaused = rideState.status == RecordingStatus.paused;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (c) => _mapCtrl = c,
            initialCameraPosition: CameraPosition(
              target: rideState.polyline.isNotEmpty
                  ? rideState.polyline.last
                  : const LatLng(23.8103, 90.4125),
              zoom: 17,
            ),
            polylines: {
              if (rideState.polyline.length > 1)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: rideState.polyline,
                  color: AppColors.primary,
                  width: 4,
                ),
            },
            markers: rideState.polyline.isNotEmpty
                ? {
                    Marker(
                      markerId: const MarkerId('current'),
                      position: rideState.polyline.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                    ),
                  }
                : {},
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
          ),

          // Alert overlay
          AnimatedBuilder(
            animation: _alertColor,
            builder: (_, __) => IgnorePointer(
              child: Container(
                color: _alertColor.value,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // Alert banner
          if (rideState.activeAlert != RideAlert.none)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _AlertBanner(alert: rideState.activeAlert),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.background, AppColors.background.withOpacity(0)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? AppColors.warning.withOpacity(0.15)
                          : AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: isPaused ? AppColors.warning : AppColors.success),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPaused ? AppColors.warning : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPaused ? 'PAUSED' : 'RECORDING',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isPaused ? AppColors.warning : AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    SpeedFormatter.durationFromDuration(rideState.elapsed),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),

          // Speed display (center)
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (rideState.currentSpeedMs * 3.6).toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -2),
                    ),
                    const Text('km/h',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.background, AppColors.background.withOpacity(0)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _RideStat(
                          label: 'Distance',
                          value: SpeedFormatter.distanceKm(rideState.distanceM)),
                      _RideStat(
                          label: 'Max Speed',
                          value: SpeedFormatter.fromMs(rideState.currentSpeedMs)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isPaused
                              ? () => ref.read(rideRecordingProvider.notifier).resumeRide()
                              : () => ref.read(rideRecordingProvider.notifier).pauseRide(),
                          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(isPaused ? 'Resume' : 'Pause'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopRide,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('End Ride'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            backgroundColor: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideStat extends StatelessWidget {
  final String label;
  final String value;
  const _RideStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final RideAlert alert;
  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final (icon, message, color) = switch (alert) {
      RideAlert.hardBraking => (Icons.warning_amber, 'Hard Braking Detected', AppColors.danger),
      RideAlert.rapidAccel => (Icons.bolt, 'Rapid Acceleration', AppColors.orange),
      RideAlert.overspeed => (Icons.speed, 'Overspeed Alert', AppColors.warning),
      RideAlert.fatigue => (Icons.bedtime_outlined, 'Fatigue Alert - Consider a break', AppColors.primary),
      _ => (Icons.info_outline, '', AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(message,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
