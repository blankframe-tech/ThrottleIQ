import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_context.dart';
import '../domain/entities/place_entity.dart';

/// The accent a category is drawn in — marker halo, card icon tile, chip
/// tint. Taken from the active palette's semantic colors so every theme
/// (dark, light, retro) stays coherent, and safety points share the danger
/// red that marks them as hazards rather than stops.
extension PlaceCategoryStyle on PlaceCategory {
  Color accent(BuildContext context) {
    final palette = context.palette;
    return switch (this) {
      PlaceCategory.fuel => palette.warning,
      PlaceCategory.garage => palette.primary,
      PlaceCategory.parts => palette.secondary,
      PlaceCategory.recreation => palette.success,
      PlaceCategory.aiCamera || PlaceCategory.police => palette.danger,
    };
  }

  IconData get markerIcon => switch (this) {
        PlaceCategory.fuel => Icons.local_gas_station,
        PlaceCategory.garage => Icons.build,
        PlaceCategory.parts => Icons.settings,
        PlaceCategory.recreation => Icons.local_cafe,
        PlaceCategory.aiCamera => Icons.photo_camera,
        PlaceCategory.police => Icons.local_police,
      };
}
