import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../ride/presentation/widgets/recording_gate.dart';
import '../../../social/domain/entities/route_entity.dart';
import '../../../../shared/widgets/app_tile_layer.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/turn_instruction.dart';
import '../nav_format.dart';
import '../providers/navigation_session_provider.dart';
import '../providers/route_providers.dart';
import 'route_detail_screen.dart' show turnIcon;
import '../turn_instruction_l10n.dart';

/// The hand-off from "I want to follow this route" to the ride cockpit.
///
/// Until issues §78.21 this screen *was* navigation: it ran its own
/// `Geolocator.getPositionStream`, its own permission and services checks and
/// its own progress maths, none of which the recorder knew about. The result
/// was the app's two core loops failing to compose — a rider could follow a
/// saved route for two hours and end up with no ride in their history, and the
/// phone had spent that time holding two GPS subscriptions open.
///
/// Now this is a pre-flight: it confirms what's about to happen, starts (or
/// attaches to) a recording, hands the route to [navigationSessionProvider]
/// and sends the rider to `/ride/active`, where guidance is drawn over the
/// cockpit by `NavigationBanner`. Everything live — GPS, sensors, the
/// foreground service, persistence, live-share, crash coordination — belongs
/// to `RideRecordingNotifier`, which is where it always should have been.
class RouteNavigationScreen extends ConsumerStatefulWidget {
  final String routeId;

  /// The rider the route belongs to, carried through from `?owner=<uid>` so a
  /// *discovered* route can be followed too. Null means "the signed-in
  /// rider". Nothing here writes to the route, so a non-owner needs no extra
  /// permission — the ride that gets recorded is the viewer's own.
  final String? ownerUid;

  const RouteNavigationScreen({
    super.key,
    required this.routeId,
    this.ownerUid,
  });

  @override
  ConsumerState<RouteNavigationScreen> createState() =>
      _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends ConsumerState<RouteNavigationScreen> {
  /// Guards against a second tap while `startRide()` is still in flight — it
  /// awaits permission prompts and a database insert, which is long enough for
  /// an impatient thumb to land twice.
  bool _starting = false;

  RouteLookup get _lookup =>
      (routeId: widget.routeId, ownerUid: widget.ownerUid);

  Future<void> _go(RouteEntity route) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final recorder = ref.read(rideRecordingProvider.notifier);
      final status = ref.read(rideRecordingProvider).status;
      final alreadyRiding = status == RecordingStatus.active ||
          status == RecordingStatus.paused;

      if (!alreadyRiding) {
        // Same Play background-location disclosure the Record button shows,
        // from the same helper — see recording_gate.dart.
        if (!await ensureLocationDisclosure(context)) return;
        if (!mounted) return;
        await recorder.startRide(routeId: route.id, routeName: route.name);
        if (!mounted) return;
        final result = ref.read(rideRecordingProvider);
        if (result.status != RecordingStatus.active) {
          // Permission denied, GPS off, no bike. Stay here and say why —
          // navigating to a cockpit with no ride in it would be a dead end.
          showRecordingBlockedSnackBar(context, result);
          return;
        }
      }

      ref.read(navigationSessionProvider.notifier).start(route);
      if (!mounted) return;
      context.go('/ride/active');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(routeByIdProvider(_lookup));
    final status = ref.watch(rideRecordingProvider.select((s) => s.status));
    final alreadyRiding =
        status == RecordingStatus.active || status == RecordingStatus.paused;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(context.l10n.startNavigation),
      ),
      body: routeAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(routeByIdProvider(_lookup)),
        ),
        data: (route) {
          if (route == null || route.polyline.length < 2) {
            return Center(
              child: Text(context.l10n.thisRouteHasNo,
                  style: TextStyle(color: context.palette.textSecondary)),
            );
          }

          final turns = buildTurnInstructions(route.polyline);
          // Start and arrive bookend every instruction list; neither is a
          // manoeuvre, and counting them would tell the rider a straight road
          // has two turns on it.
          final manoeuvres = turns
              .where((t) => t.kind != TurnKind.start && t.kind != TurnKind.arrive)
              .length;

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: route.polyline.first,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    const AppTileLayer(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.polyline,
                          strokeWidth: 5,
                          color: context.palette.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        route.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.navRoutePreflightSummary(
                          routeDistanceLabel(route.distanceKm * 1000),
                          manoeuvres,
                        ),
                        style: TextStyle(
                            fontSize: 13, color: context.palette.textSecondary),
                      ),
                      if (turns.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(turnIcon(turns.first.kind),
                                size: 20, color: context.palette.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                turns.first.localizedText(context.l10n),
                                style: TextStyle(
                                    fontSize: 14,
                                    color: context.palette.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      // The one thing a rider should know before tapping, and
                      // the whole point of §78.21: this is a ride, not just a
                      // map. Saying so beats discovering it afterwards either
                      // way round.
                      Text(
                        alreadyRiding
                            ? context.l10n.navAttachExplainer
                            : context.l10n.navRecordsRideExplainer,
                        style: TextStyle(
                            fontSize: 12, color: context.palette.textTertiary),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _starting ? null : () => _go(route),
                          icon: _starting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.navigation_outlined, size: 18),
                          label: Text(alreadyRiding
                              ? context.l10n.navGuideOnThisRide
                              : context.l10n.navStartRideAndGuide),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
