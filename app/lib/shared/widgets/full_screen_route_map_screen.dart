import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme_context.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/formatters/speed_formatter.dart';
import 'app_tile_layer.dart';

/// Dedicated full-screen interactive route map explorer.
///
/// Gives riders a large map canvas to pinch-zoom, pan, zoom in/out with
/// dedicated buttons, recenter, and tap on route waypoints to inspect
/// coordinates and progression details.
///
/// Generalized off `SharedRideEntity` (it started life inside the social
/// shared-ride-detail screen) so both a shared post and a rider's own
/// private ride summary can push the same explorer — see
/// `DOCS/Handoff for agents and Todos/issues_fixed.md`'s "why does the
/// social ride detail look cooler" note. [onSaveRoute], if given, receives
/// this screen's own `BuildContext` (so it can show its own snackbar or
/// push a route-save form on top) and is awaited to drive the save
/// button's spinner; a null value hides the save action entirely.
class FullScreenRouteMapScreen extends StatefulWidget {
  final List<LatLng> polyline;
  final String title;
  final String subtitle;
  final double distanceKm;
  final int durationSeconds;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final Future<void> Function(BuildContext context)? onSaveRoute;

  const FullScreenRouteMapScreen({
    super.key,
    required this.polyline,
    required this.title,
    required this.subtitle,
    required this.distanceKm,
    required this.durationSeconds,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    this.onSaveRoute,
  });

  @override
  State<FullScreenRouteMapScreen> createState() => _FullScreenRouteMapScreenState();
}

class _FullScreenRouteMapScreenState extends State<FullScreenRouteMapScreen> {
  final MapController _controller = MapController();
  LatLng? _selectedPoint;
  int? _selectedPointIndex;
  bool _savingRoute = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recenter() {
    if (widget.polyline.isEmpty) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: widget.polyline,
        padding: const EdgeInsets.fromLTRB(40, 90, 40, 220),
        maxZoom: 16,
      ),
    );
  }

  void _zoomIn() {
    try {
      final currentZoom = _controller.camera.zoom;
      _controller.move(_controller.camera.center, (currentZoom + 1).clamp(1.0, 18.0));
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _controller.camera.zoom;
      _controller.move(_controller.camera.center, (currentZoom - 1).clamp(1.0, 18.0));
    } catch (_) {}
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (widget.polyline.isEmpty) return;
    const distance = Distance();
    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < widget.polyline.length; i++) {
      final d = distance.as(LengthUnit.Meter, point, widget.polyline[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }
    setState(() {
      _selectedPoint = widget.polyline[closestIndex];
      _selectedPointIndex = closestIndex;
    });
  }

  Future<void> _saveRoute() async {
    final onSaveRoute = widget.onSaveRoute;
    if (onSaveRoute == null) return;
    setState(() => _savingRoute = true);
    try {
      await onSaveRoute(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save route: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final polyline = widget.polyline;
    final start = polyline.isNotEmpty ? polyline.first : null;
    final finish = polyline.length > 1 ? polyline.last : null;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: Stack(
        children: [
          // 1. Full-screen FlutterMap
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: polyline.first,
              initialZoom: 13,
              initialCameraFit: CameraFit.coordinates(
                coordinates: polyline,
                padding: const EdgeInsets.fromLTRB(40, 90, 40, 220),
                maxZoom: 16,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: _onMapTap,
            ),
            children: [
              const AppTileLayer(),
              if (polyline.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      color: context.palette.primary,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (start != null)
                    Marker(
                      point: start,
                      width: 60,
                      height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.palette.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'START',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.location_on, color: context.palette.success, size: 24),
                        ],
                      ),
                    ),
                  if (finish != null)
                    Marker(
                      point: finish,
                      width: 60,
                      height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.palette.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FINISH',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.flag, color: context.palette.danger, size: 24),
                        ],
                      ),
                    ),
                  if (_selectedPoint != null)
                    Marker(
                      point: _selectedPoint!,
                      width: 36,
                      height: 36,
                      child: Icon(Icons.navigation, color: context.palette.warning, size: 28),
                    ),
                ],
              ),
            ],
          ),

          // 2. Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                    child: IconButton(
                      tooltip: 'Back',
                      icon: Icon(Icons.arrow_back, color: context.palette.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.palette.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(context.shape.radiusFull),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                    child: IconButton(
                      tooltip: 'Close',
                      icon: Icon(Icons.close, color: context.palette.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Zoom & Recenter controls
          Positioned(
            right: 16,
            bottom: 210,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fullscreen_zoom_in',
                  key: const Key('fullscreen_zoom_in_button'),
                  backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                  foregroundColor: context.palette.textPrimary,
                  tooltip: 'Zoom In',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fullscreen_zoom_out',
                  key: const Key('fullscreen_zoom_out_button'),
                  backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                  foregroundColor: context.palette.textPrimary,
                  tooltip: 'Zoom Out',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fullscreen_recenter',
                  key: const Key('fullscreen_recenter_button'),
                  backgroundColor: context.palette.surface.withValues(alpha: 0.9),
                  foregroundColor: context.palette.textPrimary,
                  tooltip: 'Recenter Route',
                  onPressed: _recenter,
                  child: const Icon(Icons.my_location, size: 18),
                ),
              ],
            ),
          ),

          // 4. Selected waypoint callout badge (if tapped)
          if (_selectedPoint != null && _selectedPointIndex != null)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.palette.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(context.shape.radiusMd),
                  border: Border.all(color: context.palette.warning, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: context.palette.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Waypoint #${_selectedPointIndex! + 1} of ${polyline.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          Text(
                            'Lat: ${_selectedPoint!.latitude.toStringAsFixed(5)}, Lng: ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => setState(() {
                        _selectedPoint = null;
                        _selectedPointIndex = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Bottom Route Telemetry & Action Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              decoration: BoxDecoration(
                color: context.palette.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(context.shape.radiusLg),
                border: Border.all(color: context.palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _telemetryMini('Distance', '${widget.distanceKm.toStringAsFixed(1)} km'),
                      _telemetryMini('Duration', SpeedFormatter.durationFromSeconds(widget.durationSeconds)),
                      _telemetryMini('Max Speed', '${widget.maxSpeedKmh.toStringAsFixed(0)} km/h'),
                      _telemetryMini('Avg Speed', '${widget.avgSpeedKmh.toStringAsFixed(0)} km/h'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: context.palette.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: context.palette.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${polyline.length} GPS points • Tap route to inspect waypoints',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
                        ),
                      ),
                      if (widget.onSaveRoute != null)
                        TextButton.icon(
                          key: const Key('fullscreen_save_route_button'),
                          onPressed: _savingRoute ? null : _saveRoute,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: _savingRoute
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                )
                              : const Icon(Icons.bookmark_add_outlined, size: 16),
                          label: const Text('Save Route', style: TextStyle(fontSize: 12)),
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

  Widget _telemetryMini(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.palette.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: context.palette.textSecondary)),
      ],
    );
  }
}
