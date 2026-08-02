import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/turn_instruction.dart';
import '../providers/route_providers.dart';
import 'route_detail_screen.dart' show turnIcon;

/// How close the rider must get to a turn's point before it's considered done
/// and the banner advances to the next one.
const double _turnReachedM = 30;

/// Distance from the nearest point on the route past which the rider is told
/// they're off route.
const double _offRouteM = 100;

/// Live turn-by-turn guidance along a saved route.
///
/// This follows a breadcrumb trail — it does not reroute. There's no routing
/// engine behind it (see turn_instruction.dart for why), so if the rider
/// leaves the route the screen says so rather than silently inventing a new
/// path. Street names aren't available either; guidance is geometric.
class RouteNavigationScreen extends ConsumerStatefulWidget {
  final String routeId;

  /// The rider the route belongs to, carried through from `?owner=<uid>` so a
  /// *discovered* route can be followed too. Null means "the signed-in
  /// rider". Nothing here writes, so a non-owner needs no extra permission.
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
  final _mapController = MapController();

  RouteLookup get _lookup =>
      (routeId: widget.routeId, ownerUid: widget.ownerUid);

  StreamSubscription<Position>? _positionSub;
  LatLng? _position;
  double? _speedMs;
  String? _locationError;

  /// Index into the instruction list of the manoeuvre the rider is heading to.
  int _currentTurn = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    // Release the screen lock even if navigation is abandoned by a back
    // gesture rather than the End button.
    WakelockPlus.disable();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationError =
            'Location permission is off, so turns can\'t be tracked. Enable it in Settings to navigate.');
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() =>
            _locationError = 'Location services are off. Turn them on to navigate.');
        return;
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: (Object e) {
        if (!mounted) return;
        setState(() => _locationError = 'Location error: $e');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError = 'Could not start location: $e');
    }
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    final here = LatLng(p.latitude, p.longitude);
    setState(() {
      _position = here;
      _speedMs = p.speed;
    });
    _mapController.move(here, _mapController.camera.zoom);
    _advanceTurnIfReached(here);
  }

  /// Advances past every manoeuvre the rider is already within [_turnReachedM]
  /// of — a loop, not a single step, so a burst of movement (or a coarse fix
  /// after a tunnel) can't leave the banner stuck behind the rider.
  void _advanceTurnIfReached(LatLng here) {
    final route = ref.read(routeByIdProvider(_lookup)).valueOrNull;
    if (route == null) return;
    final turns = buildTurnInstructions(route.polyline);
    if (turns.isEmpty) return;

    var next = _currentTurn;
    while (next < turns.length - 1) {
      final target = route.polyline[turns[next].pointIndex];
      if (haversineMeters(here, target) > _turnReachedM) break;
      next++;
    }
    if (next != _currentTurn) setState(() => _currentTurn = next);
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(routeByIdProvider(_lookup));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: routeAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            Center(child: Text('$e', style: TextStyle(color: AppColors.danger))),
        data: (route) {
          if (route == null || route.polyline.length < 2) {
            return Center(
              child: Text('This route has no track to follow.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final turns = buildTurnInstructions(route.polyline);
          final turnIndex = _currentTurn.clamp(0, turns.length - 1);
          final turn = turns.isEmpty ? null : turns[turnIndex];

          final nearest = _position == null
              ? null
              : nearestPointOnPolyline(route.polyline, _position!);
          final offRoute = nearest != null && nearest.distanceM > _offRouteM;

          final metresToTurn = (_position != null && turn != null)
              ? haversineMeters(
                  _position!, route.polyline[turn.pointIndex])
              : null;

          final metresLeft = nearest == null
              ? route.distanceKm * 1000
              : remainingDistanceM(route.polyline, nearest.index);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _position ?? route.polyline.first,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bft.throttleiq',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route.polyline,
                        strokeWidth: 5,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      if (turn != null)
                        Marker(
                          point: route.polyline[turn.pointIndex],
                          width: 22,
                          height: 22,
                          child: Icon(Icons.circle,
                              size: 14, color: AppColors.secondary),
                        ),
                      if (_position != null)
                        Marker(
                          point: _position!,
                          width: 26,
                          height: 26,
                          child: Icon(Icons.navigation,
                              size: 24, color: AppColors.primary),
                        ),
                    ],
                  ),
                ],
              ),

              // Instruction banner
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  child: Column(
                    children: [
                      if (_locationError != null)
                        _Banner(
                          child: Text(
                            _locationError!,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        )
                      else if (turn != null)
                        _Banner(
                          child: Row(
                            children: [
                              Icon(turnIcon(turn.kind),
                                  size: 34, color: AppColors.primary),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      turn.text,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                    if (metresToTurn != null)
                                      Text(
                                        'in ${_distanceLabel(metresToTurn)}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (offRoute) ...[
                        const SizedBox(height: 8),
                        _Banner(
                          background: AppColors.danger.withOpacity(0.15),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 18, color: AppColors.danger),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Off route — ${_distanceLabel(nearest.distanceM)} from the line',
                                  style: TextStyle(
                                      fontSize: 13, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom bar
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingMd),
                    child: _Banner(
                      child: Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'Remaining',
                              value: _distanceLabel(metresLeft),
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'ETA',
                              value: _etaLabel(metresLeft, _speedMs),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text('End',
                                style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ),
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

String _distanceLabel(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// ETA from the rider's current speed. Returns '—' while stopped or before
/// the first fix — extrapolating an arrival time from 0 m/s would divide by
/// zero, and from a crawl would show an absurd number.
String _etaLabel(double metres, double? speedMs) {
  if (speedMs == null || speedMs < 1.0) return '—';
  final seconds = metres / speedMs;
  if (seconds < 60) return '<1 min';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  return '${hours}h ${minutes % 60}m';
}

class _Banner extends StatelessWidget {
  final Widget child;
  final Color? background;
  const _Banner({required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}
