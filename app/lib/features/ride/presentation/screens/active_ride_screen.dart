import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../providers/ride_recording_provider.dart';
import '../../../ride/domain/calculators/event_detector.dart';

/// Hosted live-share viewer (Firebase Hosting rewrites /live/** to the viewer).
const _liveShareBaseUrl = 'https://throttleiqfb.web.app/live';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

/// The live route map, isolated from the rest of [ActiveRideScreen] so that
/// high-frequency stat updates (speed, elapsed, filtered acceleration) don't
/// drag the tile layer and the full-ride Polyline through a rebuild with them.
class _RouteMap extends ConsumerStatefulWidget {
  const _RouteMap();

  @override
  ConsumerState<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<_RouteMap> {
  final MapController _mapCtrl = MapController();
  static const _fallbackCenter = LatLng(23.8103, 90.4125);

  @override
  Widget build(BuildContext context) {
    // Watch only what the map actually draws. polylineVersion is the change
    // signal for the route: the underlying list is mutated in place by the
    // notifier and so is reference-stable, which a plain select() on
    // `polyline` would read as "unchanged" forever.
    final version = ref.watch(
        rideRecordingProvider.select((s) => s.polylineVersion));
    final position = ref.watch(
        rideRecordingProvider.select((s) => s.currentPosition));
    final polyline = ref.read(rideRecordingProvider).polyline;

    if (position != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapCtrl.move(position, _mapCtrl.camera.zoom);
        } catch (_) {/* controller not attached yet */}
      });
    }

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: position ?? _fallbackCenter,
        initialZoom: 17,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bft.throttleiq',
        ),
        if (polyline.length > 1)
          PolylineLayer(
            key: ValueKey(version),
            polylines: [
              Polyline(
                points: polyline,
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        if (position != null)
          MarkerLayer(
            markers: [
              Marker(
                point: position,
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
    );
  }
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _alertCtrl;
  late Animation<Color?> _alertColor;
  RideAlert _lastAlert = RideAlert.none;
  // Anchors the iOS share popover to the button that triggered it. Without
  // this, UIActivityViewController can fail to present at all on some
  // iOS/share_plus combinations instead of just skipping the popover-arrow
  // styling it's documented for on iPad — which is what made the button
  // look like it silently did nothing.
  final GlobalKey _shareButtonKey = GlobalKey();
  // stopRide() resets the provider state to idle *before* _stopRide() gets
  // to run its own post-stop navigation (context.go to either the share or
  // summary screen) — stopRide()'s `state = ...` assignment notifies this
  // widget's ref.watch synchronously, so the idle-redirect below used to
  // schedule its own postFrameCallback to '/home/record' first and clobber
  // whichever destination _stopRide() actually wanted, e.g. "Share ride"
  // being checked in the end-ride dialog never actually landing on the share
  // screen. Suppress the generic redirect while we're driving navigation
  // ourselves.
  bool _endingRide = false;

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
        flashColor = AppColors.secondary.withValues(alpha: 0.3);
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

  void _shareLiveLocation(String token) {
    // See _shareButtonKey's doc comment for why this is computed at all.
    Rect? origin;
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    Share.share(
      'Follow my ride live: $_liveShareBaseUrl/$token',
      subject: 'ThrottleIQ live ride',
      sharePositionOrigin: origin,
    );
  }

  Future<void> _stopRide() async {
    var shareAfterEnd = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('End Ride?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Your ride will be saved.',
              style: TextStyle(color: AppColors.textSecondary)),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    GestureDetector(
                      onTap: () => setDialogState(() => shareAfterEnd = !shareAfterEnd),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Share ride',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          Checkbox(
                            value: shareAfterEnd,
                            activeColor: AppColors.primary,
                            onChanged: (v) =>
                                setDialogState(() => shareAfterEnd = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                    child: const Text('End Ride'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    _endingRide = true;
    final rideId = await ref.read(rideRecordingProvider.notifier).stopRide();
    if (!mounted) return;
    if (rideId == null) {
      context.go('/home/record');
    } else if (shareAfterEnd) {
      context.go('/ride/share/$rideId');
    } else {
      context.go('/ride/summary/$rideId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideRecordingProvider);

    if (rideState.status == RecordingStatus.idle ||
        rideState.status == RecordingStatus.completed) {
      if (!_endingRide) {
        WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home/record'));
      }
      return const SizedBox.shrink();
    }

    // Camera following moved into _RouteMap, which is driven by position
    // updates rather than by every rebuild of this screen — this callback
    // used to issue a MapController.move() on each build, i.e. as often as
    // the accelerometer pushed state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAlert(rideState.activeAlert);
    });

    final isPaused = rideState.status == RecordingStatus.paused;
    final speedKmh = rideState.currentSpeedMs * 3.6;
    final accel = rideState.sensorAccelMs2;
    final avgSpeedKmh = rideState.elapsed.inSeconds > 0
        ? (rideState.distanceM / rideState.elapsed.inSeconds) * 3.6
        : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          //
          // Deliberately `const`: this screen rebuilds on every speed, elapsed
          // and accelerometer tick, and an identical const child lets Flutter
          // skip the whole map subtree — tile layer, route polyline and all —
          // on those rebuilds. _RouteMap subscribes to just the route/position
          // slices of the recording state, so it still updates when the route
          // actually moves. Inlining the map here instead meant re-rendering a
          // Polyline of the entire ride many times a second.
          const _RouteMap(),

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
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  if (rideState.liveSessionToken != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      key: _shareButtonKey,
                      onPressed: () => _shareLiveLocation(rideState.liveSessionToken!),
                      icon: Icon(Icons.share_location,
                          color: AppColors.textPrimary),
                      tooltip: 'Share live location',
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Speed + sensor display ────────────────────────────────────────
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Real GPS fixes arrive in discrete steps (every few
                    // hundred ms to a couple seconds, depending on speed and
                    // signal — see _startLocationStream's tuning notes) so a
                    // plain Text here visibly jumps between values. Tweening
                    // toward each new reading instead of snapping to it
                    // makes the number feel continuous even though the
                    // underlying fixes aren't — reported as "speed updates
                    // feel slow," and tightening the GPS settings alone
                    // still leaves discrete jumps between real fixes.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: speedKmh, end: speedKmh),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      builder: (context, value, child) => Text(
                        value.toStringAsFixed(0),
                        style: display(64, weight: FontWeight.w700, letterSpacing: -3, height: 1),
                      ),
                    ),
                    Text('km/h',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RideStat(
                            label: 'Distance',
                            value: SpeedFormatter.distanceKm(rideState.distanceM)),
                        const SizedBox(width: 28),
                        _RideStat(
                            label: 'Avg Speed',
                            value: '${avgSpeedKmh.toStringAsFixed(0)} km/h'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Sensor G-force indicator
                    _GForceBar(accelMs2: accel),
                  ],
                ),
              ),
            ),
          ),

          // ── Pause dim ─────────────────────────────────────────────────────
          // Sits above the map/top bar/speed panel but below the bottom
          // controls, so pausing darkens everything except the buttons you'd
          // actually reach for.
          if (isPaused)
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xCC000000)),
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
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: isPaused
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.65),
                                  blurRadius: 26,
                                  spreadRadius: 1,
                                ),
                              ],
                            )
                          : null,
                      child: OutlinedButton.icon(
                        onPressed: isPaused
                            ? () => ref.read(rideRecordingProvider.notifier).resumeRide()
                            : () => ref.read(rideRecordingProvider.notifier).pauseRide(),
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(isPaused ? 'Resume' : 'Pause'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: isPaused ? AppColors.surface : null,
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                        ),
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
            ),
          ),

          // ── Crash countdown overlay (topmost) ────────────────────────────
          if (rideState.crashDetected)
            _CrashOverlay(
              countdown: rideState.crashCountdown,
              onImOk: () =>
                  ref.read(rideRecordingProvider.notifier).dismissCrashAlert(),
            ),
        ],
      ),
    );
  }
}

/// Full-screen "Are you OK?" takeover shown when crash detection fires.
/// Counts down from 60; if it reaches 0 the provider notifies emergency
/// contacts. The big I'M OK button dismisses and logs a false positive.
class _CrashOverlay extends StatelessWidget {
  final int countdown;
  final VoidCallback onImOk;

  const _CrashOverlay({required this.countdown, required this.onImOk});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xE6B71C1C), // urgent red, ~90% opaque
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 72),
              const SizedBox(height: 16),
              const Text(
                'CRASH DETECTED',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Are you OK? Your emergency contacts will be notified when the timer ends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '$countdown',
                style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1),
              ),
              const Text('seconds',
                  style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: ElevatedButton(
                    onPressed: onImOk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB71C1C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "I'M OK",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            ? AppColors.secondary
            : AppColors.success;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BRAKE', style: TextStyle(fontSize: 9, color: AppColors.textTertiary, letterSpacing: 0.5)),
            Text(
              '${gForce.abs().toStringAsFixed(2)}g',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            Text('ACCEL', style: TextStyle(fontSize: 9, color: AppColors.textTertiary, letterSpacing: 0.5)),
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
    final color = isPaused ? AppColors.attention : AppColors.danger;
    final label = isPaused ? 'PAUSED' : 'RECORDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.onInk)),
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
        Text(value, style: display(18, letterSpacing: 0)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final RideAlert alert;
  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final (message, color) = switch (alert) {
      RideAlert.hardBraking => ('Ease on the brakes', AppColors.danger),
      RideAlert.rapidAccel => ('Smooth on the throttle', AppColors.attention),
      RideAlert.overspeed => ('Watch your speed', AppColors.attention),
      RideAlert.fatigue => ('Time for a break', AppColors.primary),
      _ => ('', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.06), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message,
                style: display(14, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}
