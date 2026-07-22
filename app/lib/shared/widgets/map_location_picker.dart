import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// A "drop a pin" location picker: the map pans freely underneath a fixed
/// center pin (the same interaction pattern Google/Uber use for pin-drop) —
/// simpler and more reliable than drag-a-marker gestures in `flutter_map`
/// without extra plugins. Reports the panned-to point via [onLocationChanged]
/// as the map moves.
class MapLocationPicker extends StatefulWidget {
  final LatLng initialCenter;
  final ValueChanged<LatLng> onLocationChanged;
  final double height;

  const MapLocationPicker({
    super.key,
    required this.initialCenter,
    required this.onLocationChanged,
    this.height = 220,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: 15,
                onPositionChanged: (camera, hasGesture) =>
                    widget.onLocationChanged(camera.center),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bft.throttleiq',
                ),
              ],
            ),
            // Fixed center pin — the map moves, this stays put. Offset up by
            // half its height so the pin's *tip* (not its center) marks the
            // picked point, matching how a real map pin reads.
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Icon(Icons.location_pin, size: 40, color: AppColors.primary),
            ),
            IgnorePointer(
              child: Container(
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: const Text('Drag map to move pin',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
