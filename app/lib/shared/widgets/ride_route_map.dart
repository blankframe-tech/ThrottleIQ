import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// A small, non-interactive map that draws a ride's recorded route — the
/// Strava-style trace shown on social feed cards.
///
/// Auto-fits the camera to the polyline's bounds (with a little padding) and
/// marks the start/end. Degrades gracefully: an empty polyline renders a
/// bordered placeholder rather than a blank world map. That case is normal,
/// not an error — PrivacyZoneClipper strips ~200 m off each end at share
/// time and can legitimately consume a short ride's entire track.
class RideRouteMap extends StatelessWidget {
  final List<LatLng> polyline;
  final double height;

  /// Corner radius of the clipped map surface.
  final double radius;

  const RideRouteMap({
    super.key,
    required this.polyline,
    this.height = 160,
    this.radius = AppDimensions.radiusLg,
  });

  @override
  Widget build(BuildContext context) {
    if (polyline.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 22, color: AppColors.textTertiary),
              const SizedBox(height: 6),
              Text(
                'No route recorded',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: polyline.first,
            initialZoom: polyline.length > 1 ? 13 : 15,
            initialCameraFit: CameraFit.coordinates(
              coordinates: polyline,
              padding: const EdgeInsets.all(24),
              maxZoom: 16,
            ),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bft.throttleiq',
            ),
            if (polyline.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                      points: polyline,
                      color: AppColors.primary,
                      strokeWidth: 4),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: polyline.first,
                  width: 14,
                  height: 14,
                  child: _endpointDot(AppColors.success),
                ),
                if (polyline.length > 1)
                  Marker(
                    point: polyline.last,
                    width: 14,
                    height: 14,
                    child: _endpointDot(AppColors.danger),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _endpointDot(Color color) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
}
