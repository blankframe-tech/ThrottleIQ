import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../../social/domain/entities/route_entity.dart';
import '../../domain/navigation_progress.dart';
import '../../domain/turn_instruction.dart';

/// Turn-by-turn guidance for a saved route, layered on top of a ride that is
/// already being recorded (issues §78.21).
///
/// The point of this provider is what it *doesn't* own: there is no GPS
/// stream here, no permission check and no wakelock. It listens to
/// [rideRecordingProvider] and recomputes progress from the fixes the recorder
/// is already taking. Before this, `RouteNavigationScreen` ran its own
/// `Geolocator.getPositionStream` in parallel with the recorder's — two
/// subscriptions, two batteries' worth of GPS, and a ride that wasn't being
/// logged at all while the rider followed a route.
///
/// Dependency direction is deliberately one-way: routes knows about the
/// recorder, the recorder knows nothing about routes. That keeps navigation
/// out of the app's core loop, which is the part with no end-to-end test
/// (issues §83.28).
class NavigationSessionState extends Equatable {
  /// The route being followed, or null when nothing is being navigated.
  final RouteEntity? route;

  /// Manoeuvres derived from [route]'s polyline, computed once at [start].
  final List<TurnInstruction> turns;

  final NavigationProgress progress;

  const NavigationSessionState({
    this.route,
    this.turns = const [],
    this.progress = const NavigationProgress(
      turnIndex: -1,
      metresToTurn: null,
      metresRemaining: 0,
      offRouteM: null,
      etaSeconds: null,
      arrived: false,
    ),
  });

  bool get isActive => route != null;

  /// The manoeuvre the rider is heading toward, or null when there is none
  /// (nothing being navigated, or a route with no usable shape).
  TurnInstruction? get currentTurn =>
      (progress.turnIndex >= 0 && progress.turnIndex < turns.length)
          ? turns[progress.turnIndex]
          : null;

  List<LatLng> get polyline => route?.polyline ?? const [];

  @override
  List<Object?> get props => [route?.id, turns.length, progress];
}

class NavigationSessionNotifier extends StateNotifier<NavigationSessionState> {
  NavigationSessionNotifier() : super(const NavigationSessionState());

  /// Begins following [route]. Safe to call while a ride is already running —
  /// that is the normal case, since the cockpit is what displays this.
  void start(RouteEntity route) {
    final turns = buildTurnInstructions(route.polyline);
    state = NavigationSessionState(
      route: route,
      turns: turns,
      progress: turns.isEmpty
          ? const NavigationProgress(
              turnIndex: -1,
              metresToTurn: null,
              metresRemaining: 0,
              offRouteM: null,
              etaSeconds: null,
              arrived: false,
            )
          : NavigationProgress.initial(route.polyline),
    );
  }

  /// Stops guidance. Does **not** touch the ride: a rider who gives up on the
  /// route is still out riding, and the recording carries on.
  void stop() {
    if (!state.isActive) return;
    state = const NavigationSessionState();
  }

  /// Fold one recording-state change into the session.
  ///
  /// Called from the provider's listener rather than by the recorder, so the
  /// recorder has no idea this exists. A paused ride deliberately does not
  /// advance: `pauseRide()` suspends the location subscription, so the last
  /// fix is stale and stepping the banner on it would move guidance while the
  /// bike is stationary.
  void onRecordingState(RideRecordingState ride) {
    if (!state.isActive) return;

    if (ride.status == RecordingStatus.idle ||
        ride.status == RecordingStatus.completed) {
      stop();
      return;
    }
    if (ride.status != RecordingStatus.active) return;

    final position = ride.currentPosition;
    if (position == null) return;

    state = NavigationSessionState(
      route: state.route,
      turns: state.turns,
      progress: computeNavigationProgress(
        polyline: state.polyline,
        turns: state.turns,
        previousTurnIndex: state.progress.turnIndex,
        position: position,
        speedMs: ride.currentSpeedMs,
      ),
    );
  }
}

final navigationSessionProvider =
    StateNotifierProvider<NavigationSessionNotifier, NavigationSessionState>(
        (ref) {
  final notifier = NavigationSessionNotifier();
  // Selected down to the three fields guidance actually reads. The recording
  // state itself changes as often as the accelerometer ticks; recomputing an
  // O(route length) nearest-point search at that rate would be pure waste.
  // Records compare structurally, so this fires at GPS-fix cadence instead.
  ref.listen<(LatLng?, double, RecordingStatus)>(
    rideRecordingProvider
        .select((s) => (s.currentPosition, s.currentSpeedMs, s.status)),
    (_, __) => notifier.onRecordingState(ref.read(rideRecordingProvider)),
  );
  return notifier;
});
