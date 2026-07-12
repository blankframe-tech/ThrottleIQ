import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapCtrl = MapController();
  late AnimationController _alertCtrl;
  late Animation<Color?> _alertColor;
  RideAlert _lastAlert = RideAlert.none;

  @override
  void initState() {
    super.initState();
    _alertCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
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
        flashColor = AppColors.danger.withValues(alpha: 0.4);
        break;
      case RideAlert.rapidAccel:
        flashColor = AppColors.orange.withValues(alpha: 0.3);
        break;
      case RideAlert.overspeed:
        flashColor = AppColors.warning.withValues(alpha: 0.3);
        break;
      case RideAlert.fatigue:
        flashColor = AppColors.primary.withValues(alpha: 0.3);
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
        content: const Text('Your ride will be saved.',
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
      context.go(rideId != null ? '/ride/summary/$rideId' : '/home/record');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideRecordingProvider);

    if (rideState.status == RecordingStatus.idle ||
        rideState.status == RecordingStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home/record'));
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAlert(rideState.activeAlert);
      if (rideState.polyline.isNotEmpty) {
        try {
          _mapCtrl.move(rideState.polyline.last, 17);
        } catch (_) {}
      }
    });

    final isPaused = rideState.status == RecordingStatus.paused;
    final speedKmh = rideState.currentSpeedMs * 3.6;
    final accel = rideState.sensorAccelMs2;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: rideState.polyline.isNotEmpty
                  ? rideState.polyline.last
                  : const LatLng(23.8103, 90.4125),
              initialZoom: 17,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.throttleiq.throttleiq',
              ),
              if (rideState.polyline.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: rideState.polyline,
                      color: AppColors.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              if (rideState.polyline.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: rideState.polyline.last,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Alert overlay flash ───────────────────────────────────────────
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

          // ── Alert banner ─────────────────────────────────────────────────
          if (rideState.activeAlert != RideAlert.none)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: _AlertBanner(alert: rideState.activeAlert),
            ),

          // ── Top bar ───────────────────────────────────────────────────────
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
                  colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
                ),
              ),
              child: Row(
                children: [
                  _StatusPill(isPaused: isPaused),
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

          // ── Speed + sensor display ────────────────────────────────────────
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speedKmh.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -3,
                          height: 1),
                    ),
                    const Text('km/h',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    // Sensor G-force indicator
                    _GForceBar(accelMs2: accel),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom controls ───────────────────────────────────────────────
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
                  colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
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
                          value: '${(rideState.currentSpeedMs * 3.6).toStringAsFixed(0)} km/h'),
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

// G-force bar widget using sensor data
class _GForceBar extends StatelessWidget {
  final double accelMs2;
  const _GForceBar({required this.accelMs2});

  @override
  Widget build(BuildContext context) {
    final gForce = accelMs2 / 9.81;
    final clamped = gForce.clamp(-1.5, 1.5);
    final fraction = (clamped + 1.5) / 3.0; // 0.0 to 1.0
    final color = accelMs2 < -4
        ? AppColors.danger
        : accelMs2 > 4
            ? AppColors.orange
            : AppColors.success;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('BRAKE', style: TextStyle(fontSize: 9, color: AppColors.textTertiary, letterSpacing: 0.5)),
            Text(
              '${gForce.abs().toStringAsFixed(2)}g',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            const Text('ACCEL', style: TextStyle(fontSize: 9, color: AppColors.textTertiary, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: AppColors.border),
              // Center marker
              Positioned(
                left: 0,
                right: 0,
                child: Center(
                  child: Container(width: 2, height: 6, color: AppColors.textTertiary),
                ),
              ),
              // Fill from center
              Positioned(
                left: fraction < 0.5
                    ? fraction * MediaQuery.sizeOf(context).width * 0.4
                    : MediaQuery.sizeOf(context).width * 0.4 * 0.5,
                width: (fraction - 0.5).abs() * MediaQuery.sizeOf(context).width * 0.4,
                top: 0,
                bottom: 0,
                child: Container(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isPaused;
  const _StatusPill({required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final color = isPaused ? AppColors.warning : AppColors.success;
    final label = isPaused ? 'PAUSED' : 'RECORDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: color)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
      RideAlert.fatigue => (Icons.bedtime_outlined, 'Fatigue Alert — Take a break', AppColors.primary),
      _ => (Icons.info_outline, '', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
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
