import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../providers/ride_recording_provider.dart';
import '../providers/live_ride_places_provider.dart';
import '../widgets/end_ride_sheet.dart';
import '../../../ride/domain/calculators/event_detector.dart';
import '../../../../shared/widgets/app_tile_layer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../routes/presentation/providers/navigation_session_provider.dart';
import '../../../routes/presentation/providers/route_providers.dart';
import '../../../social/data/repositories/route_repository.dart';
import '../../domain/entities/ride_entity.dart';
import '../../../routes/presentation/widgets/navigation_banner.dart';

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
    final places = ref.watch(liveRidePlacesProvider);
    // The saved route being followed, when there is one (issues §78.21).
    // Keyed on the route's id rather than watching the whole session: the
    // session's progress changes on every fix, and the line it draws does not.
    final navRouteId =
        ref.watch(navigationSessionProvider.select((s) => s.route?.id));
    final navPolyline = navRouteId == null
        ? const <LatLng>[]
        : ref.read(navigationSessionProvider).polyline;

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
        const AppTileLayer(),
        // Underneath the ride's own trail, and dimmer: the route is the plan,
        // the trail is what actually happened, and when they diverge the
        // rider needs to see which line is which.
        if (navPolyline.length > 1)
          PolylineLayer(
            key: ValueKey('nav-$navRouteId'),
            polylines: [
              Polyline(
                points: navPolyline,
                color: context.palette.secondary.withValues(alpha: 0.7),
                strokeWidth: 6,
              ),
            ],
          ),
        if (polyline.length > 1)
          PolylineLayer(
            key: ValueKey(version),
            polylines: [
              Polyline(
                points: polyline,
                color: context.palette.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final p in places)
              Marker(
                point: LatLng(p.latitude, p.longitude),
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.palette.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.category.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            if (position != null)
              Marker(
                point: position,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.palette.primary,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: context.palette.primary.withValues(alpha: 0.5),
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
  // Guards against a re-tap while the first enableLiveSharing() call is
  // still in flight (up to 8s per Firestore write on a slow connection) and
  // drives the button's spinner so the tap doesn't read as unresponsive.
  bool _sharingLive = false;
  // stopRide() resets the provider state to idle *before* _stopRide() gets
  // to run its own post-stop navigation (context.go to either the share or
  // summary screen) — stopRide()'s `state = ...` assignment notifies this
  // widget's ref.watch synchronously, so the idle-redirect below used to
  // schedule its own postFrameCallback to '/home/record' first and clobber
  // whichever destination _stopRide() actually wanted, e.g. "Share ride"
  // being on in the end-ride sheet never actually landing on the share
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
        flashColor = context.palette.danger.withValues(alpha: 0.4);
        break;
      case RideAlert.rapidAccel:
        flashColor = context.palette.secondary.withValues(alpha: 0.3);
        break;
      case RideAlert.overspeed:
        flashColor = context.palette.warning.withValues(alpha: 0.3);
        break;
      case RideAlert.fatigue:
        flashColor = context.palette.primary.withValues(alpha: 0.3);
        break;
      default:
        return;
    }
    _alertColor = ColorTween(begin: flashColor, end: Colors.transparent)
        .animate(CurvedAnimation(parent: _alertCtrl, curve: Curves.easeOut));
    _alertCtrl.forward(from: 0);
  }

  /// Tapping this button IS the opt-in (issues §24.1). Publishing
  /// used to start the instant a ride began, whether or not the rider ever
  /// meant to share it; now nothing is published until this runs.
  /// `enableLiveSharing()` is a no-op if sharing is already on, so re-tapping
  /// to re-share an in-progress session is still just one call.
  Future<void> _shareLiveLocation() async {
    if (_sharingLive) return;
    setState(() => _sharingLive = true);
    try {
      final notifier = ref.read(rideRecordingProvider.notifier);
      await notifier.enableLiveSharing();
      final token = ref.read(rideRecordingProvider).liveSessionToken;
      if (token == null || !mounted) return;

      // See _shareButtonKey's doc comment for why this is computed at all.
      Rect? origin;
      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      Share.share(
        context.l10n.followMyRideLive('$_liveShareBaseUrl/$token'),
        subject: context.l10n.throttleiqLiveRide,
        sharePositionOrigin: origin,
      );
    } finally {
      if (mounted) setState(() => _sharingLive = false);
    }
  }

  /// Once sharing is on, the same button offers the way back out — §78.7.
  /// Before this, the only way to revoke a live link was to end the ride
  /// (and even that left it readable until the 24h expiry).
  Future<void> _onLiveShareTap() async {
    if (ref.read(rideRecordingProvider).liveSessionToken == null) {
      return _shareLiveLocation();
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share, color: sheetContext.palette.textPrimary),
              title: Text(AppLocalizations.of(sheetContext).liveShareAgainAction,
                  style: TextStyle(color: sheetContext.palette.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
            ListTile(
              leading: Icon(Icons.location_off, color: sheetContext.palette.danger),
              title: Text(AppLocalizations.of(sheetContext).liveShareStopAction,
                  style: TextStyle(color: sheetContext.palette.danger)),
              subtitle: Text(
                AppLocalizations.of(sheetContext).liveShareStopDescription,
                style: TextStyle(color: sheetContext.palette.textSecondary),
              ),
              onTap: () => Navigator.pop(sheetContext, 'stop'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'share') {
      await _shareLiveLocation();
    } else if (action == 'stop') {
      await ref.read(rideRecordingProvider.notifier).stopLiveSharing();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.liveSharingStopped)),
      );
    }
  }

  Future<void> _stopRide() async {
    // Bottom sheet with a hold-to-end control rather than an AlertDialog —
    // see showEndRideSheet for why. A null choice means "keep riding".
    final choice = await showEndRideSheet(context);
    if (!mounted || choice == null) return;
    final shareAfterEnd = choice.share;
    // Read before stopping: stopRide() resets the provider to idle, taking the
    // ride entity with it.
    final finishedRide = ref.read(rideRecordingProvider).ride;
    _endingRide = true;
    final rideId = await ref.read(rideRecordingProvider.notifier).stopRide();
    _recordRouteRidden(finishedRide);
    if (!mounted) return;
    if (rideId == null) {
      context.go('/home/record');
    } else if (shareAfterEnd) {
      context.go('/ride/share/$rideId');
    } else {
      context.go('/ride/summary/$rideId');
    }
  }

  /// Counts a finished ride against the saved route it followed (issues §85).
  ///
  /// Called from [_stopRide] only, never from [_cancelRide]: a discarded ride
  /// is one that did not happen as far as the rider is concerned, and a
  /// "ridden 4×" that counts abandoned attempts is the same dead number §85
  /// was raised about. Bumping on *completion* rather than on start is the
  /// same reasoning.
  ///
  /// Lives here rather than in `RideRecordingNotifier` on purpose — the
  /// recorder knows nothing about routes, and that one-way dependency is what
  /// keeps navigation out of the core loop (§78.21).
  void _recordRouteRidden(RideEntity? ride) {
    final routeId = ride?.routeId;
    if (ride == null || routeId == null) return;
    unawaited(RouteRepository()
        .incrementTimesRidden(ride.userId, routeId)
        .then((_) {
      // The list and the detail screen both render the counter.
      ref.invalidate(myRoutesProvider);
      ref.invalidate(routeByIdProvider);
    }));
  }

  /// Throws the ride away without saving it. Worded as bluntly as the action
  /// is — this is the one control on the screen with no undo, so the dialog
  /// says what is lost rather than asking a polite "are you sure?", and the
  /// destructive choice is the one that has to be reached for.
  Future<void> _cancelRide() async {
    final rideState = ref.read(rideRecordingProvider);
    final distance = SpeedFormatter.distanceKm(rideState.distanceM);
    final duration = SpeedFormatter.durationFromDuration(rideState.elapsed);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.surface,
        title: Text(ctx.l10n.discardThisRide,
            style: TextStyle(color: ctx.palette.textPrimary)),
        content: Text(
          ctx.l10n.overWillBeDeleted(distance, duration),
          style: TextStyle(color: ctx.palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ctx.l10n.keepRecording),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ctx.l10n.discard, style: TextStyle(color: ctx.palette.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Same suppression as _stopRide: cancelRide() resets the provider to idle
    // synchronously, and the generic idle-redirect below would otherwise race
    // this navigation.
    _endingRide = true;
    await ref.read(rideRecordingProvider.notifier).cancelRide();
    if (!mounted) return;
    context.go('/home/record');
  }

  @override
  Widget build(BuildContext context) {
    // Only the three fields that change the SHAPE of this screen (issues
    // §83.12). Watching the whole 21-field state rebuilt all ~880 lines of it
    // on every accelerometer sample, every GPS fix and every clock tick —
    // with the map, the foreground service and 20-50 Hz IMU already running.
    // The readouts that genuinely do change that fast now sit in their own
    // widgets below, each selecting only its own fields, so a speed update
    // repaints a number instead of the cockpit.
    final rideState = ref.watch(rideRecordingProvider.select((s) => (
          status: s.status,
          activeAlert: s.activeAlert,
          restoredFromPreviousSession: s.restoredFromPreviousSession,
        )));

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
    // A second narrow watch rather than a field on the record above: this
    // flips at most twice a ride, so rebuilding the frame for it is free.
    final sharingLive = ref.watch(
        rideRecordingProvider.select((s) => s.liveSessionToken != null));

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

          // ── Pause dim ─────────────────────────────────────────────────────
          // Directly above the map and nothing else: pausing darkens the
          // route so the state reads at a glance, while the top bar, the speed
          // panel and the controls stay at full
          // contrast. It used to cover the stats too, which is exactly when a
          // stopped rider glances down at them.
          if (isPaused)
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xCC000000)),
                ),
              ),
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

          // ── Top banner stack ──────────────────────────────────────────────
          //
          // One column rather than three separately-positioned banners all
          // claiming `top + 72`: turn guidance has a variable height (the
          // off-route row comes and goes), so any fixed offset for what sits
          // below it would overlap sooner or later. Guidance leads because
          // it's the only one that changes what the rider does *next*.
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NavigationBanner(),
                if (rideState.activeAlert != RideAlert.none)
                  _AlertBanner(alert: rideState.activeAlert)
                // Only after a restore, and only until the rider resumes.
                // Without it, coming back to a paused ride you never paused
                // reads as a bug.
                else if (rideState.restoredFromPreviousSession)
                  const _RecoveredBanner(),
              ],
            ),
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
                  colors: [context.palette.background, context.palette.background.withValues(alpha: 0)],
                ),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  const _RideClock(),
                  const SizedBox(width: 8),
                  IconButton(
                    key: _shareButtonKey,
                    onPressed: _sharingLive ? null : _onLiveShareTap,
                    // Filled once sharing is actually on, outlined beforehand
                    // — the icon itself communicates the opt-in state, since
                    // tapping it is what turns sharing on in the first place.
                    icon: _sharingLive
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.palette.textPrimary,
                            ),
                          )
                        : Icon(
                            sharingLive
                                ? Icons.share_location
                                : Icons.location_disabled,
                            color: context.palette.textPrimary,
                          ),
                    tooltip: sharingLive
                        ? context.l10n.liveSharing
                        : context.l10n.turnShareLiveLocation,
                  ),
                ],
              ),
            ),
          ),

          // ── Speed + sensor display ────────────────────────────────────────
          const _SpeedPanel(),

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
                  colors: [context.palette.background, context.palette.background.withValues(alpha: 0)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: isPaused
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.palette.primary.withValues(alpha: 0.65),
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
                            label: Text(isPaused ? context.l10n.resume : context.l10n.pause),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              backgroundColor: isPaused ? context.palette.surface : null,
                              foregroundColor: context.palette.primary,
                              side: BorderSide(color: context.palette.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopRide,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(context.l10n.endRide),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            backgroundColor: context.palette.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Discard sits below the pair, as a text button rather than
                  // a third equal-weight control: "end and save" is what
                  // almost every ride wants, and a delete-my-data action
                  // shouldn't be the same size and shape as the one next to
                  // it that keeps everything.
                  TextButton.icon(
                    onPressed: _cancelRide,
                    icon: Icon(Icons.delete_outline, size: 18, color: context.palette.textSecondary),
                    label: Text(
                      context.l10n.discardRide,
                      style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Crash countdown overlay (topmost) ────────────────────────────
          // Its own widget because the countdown ticks once a second while
          // it's up, and nothing else on this screen should repaint for that.
          const _CrashOverlayGate(),
        ],
      ),
    );
  }
}

/// The cockpit's big speed readout, its three stats and the G-force bar.
///
/// Split out of [ActiveRideScreen.build] for issues §83.12: these are the
/// values that genuinely change many times a second, so they are the ones
/// that should own the rebuild. Selecting the six fields it actually draws
/// means an accelerometer sample repaints this panel and nothing else — the
/// map, the banners, the top bar and the controls all stay put.
class _SpeedPanel extends ConsumerWidget {
  const _SpeedPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(rideRecordingProvider.select((s) => (
          currentSpeedMs: s.currentSpeedMs,
          distanceM: s.distanceM,
          movingSeconds: s.movingSeconds,
          elapsed: s.elapsed,
          confidence: s.confidence,
          sensorAccelMs2: s.sensorAccelMs2,
        )));

    final speedKmh = s.currentSpeedMs * 3.6;
    final accel = s.sensorAccelMs2;
    final avgSpeedKmh = s.movingSeconds > 0
        ? (s.distanceM / s.movingSeconds) * 3.6
        : (s.elapsed.inSeconds > 0
            ? (s.distanceM / s.elapsed.inSeconds) * 3.6
            : 0.0);

    return Positioned(
    bottom: 160,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: context.palette.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.palette.border),
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
                style: display(context, 64, weight: FontWeight.w700, letterSpacing: -3, height: 1),
              ),
            ),
            Text('km/h', style: AppTypography.cockpitLabel(context)),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RideStat(
                    label: context.l10n.distanceLabel,
                    value: SpeedFormatter.distanceKm(s.distanceM)),
                const SizedBox(width: 24),
                _RideStat(
                    label: context.l10n.avgSpeed,
                    value: '${avgSpeedKmh.toStringAsFixed(0)} km/h'),
                if (s.confidence > 0) ...[
                  const SizedBox(width: 24),
                  _RideStat(
                      label: context.l10n.confidence,
                      value: '${s.confidence}%'),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Sensor G-force indicator
            _GForceBar(accelMs2: accel),
          ],
        ),
      ),
    ),
  );
  }
}

/// The ride clock in the top bar. One field, one `Text`, once a second —
/// rather than the whole cockpit once a second (issues §83.12).
class _RideClock extends ConsumerWidget {
  const _RideClock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed =
        ref.watch(rideRecordingProvider.select((s) => s.elapsed));
    return Text(
      SpeedFormatter.durationFromDuration(elapsed),
      style: AppTypography.cockpitValue(context),
    );
  }
}

/// Shows [_CrashOverlay] while a crash countdown is running, and nothing
/// otherwise. Separate so the once-a-second countdown doesn't drag the rest
/// of the cockpit through a rebuild with it.
class _CrashOverlayGate extends ConsumerWidget {
  const _CrashOverlayGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crash = ref.watch(rideRecordingProvider.select(
        (s) => (detected: s.crashDetected, countdown: s.crashCountdown)));
    if (!crash.detected) return const SizedBox.shrink();
    return _CrashOverlay(
      countdown: crash.countdown,
      onImOk: () => ref.read(rideRecordingProvider.notifier).dismissCrashAlert(),
    );
  }
}

/// Shown once, on a ride that was picked back up off disk at launch — see
/// [RideRecordingNotifier.restoreInterruptedRide].
class _RecoveredBanner extends StatelessWidget {
  const _RecoveredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
        border: Border.all(color: context.palette.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.restore, size: 20, color: context.palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.rideKeptFromLast, style: display(context, 14, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(
                  context.l10n.resumeCarryDiscardIt,
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
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
              Text(
                context.l10n.crashDetected,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  context.l10n.okEmergencyContactsWill,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
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
              Text(context.l10n.seconds,
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
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
                    child: Text(
                      context.l10n.imOk,
                      style: const TextStyle(
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
        ? context.palette.danger
        : accelMs2 > 4
            ? context.palette.secondary
            : context.palette.success;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.l10n.brakeCaps, style: AppTypography.cockpitLabel(context, letterSpacing: 0.5)),
            Text(
              '${gForce.abs().toStringAsFixed(2)}g',
              style: AppTypography.cockpitValue(context, color: color, weight: FontWeight.w600),
            ),
            Text(context.l10n.accelCaps, style: AppTypography.cockpitLabel(context, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: context.palette.border),
              // Center marker
              Positioned(
                left: 0,
                right: 0,
                child: Center(
                  child: Container(width: 2, height: 6, color: context.palette.textTertiary),
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

class _RideStat extends StatelessWidget {
  final String label;
  final String value;
  const _RideStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.cockpitValue(context)),
        Text(label, style: AppTypography.cockpitLabel(context)),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final RideAlert alert;
  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    // Localized, unlike most of this screen: these four are the app's safety
    // alerts, and an English-only safety alert in a Bangladesh-first app is
    // the wrong thing to leave untranslated (issues §83.23).
    final l10n = AppLocalizations.of(context);
    final (message, color) = switch (alert) {
      RideAlert.hardBraking => (l10n.rideAlertHardBraking, context.palette.danger),
      RideAlert.rapidAccel => (l10n.rideAlertRapidAccel, context.palette.attention),
      RideAlert.overspeed => (l10n.rideAlertOverspeed, context.palette.attention),
      RideAlert.fatigue => (l10n.rideAlertFatigue, context.palette.primary),
      _ => ('', context.palette.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.palette.border),
        boxShadow: [
          BoxShadow(color: context.palette.ink.withValues(alpha: 0.06), blurRadius: 12),
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
                style: display(context, 14, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}
