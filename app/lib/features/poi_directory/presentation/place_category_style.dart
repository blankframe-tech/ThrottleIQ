import 'dart:math' as math;

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

/// Dark ink drawn on light marker fills.
const Color markerDarkInk = Color(0xFF1A1A1A);

/// Icon colour for a glyph drawn on a filled [accent] marker: white or
/// [markerDarkInk], whichever contrasts more (issues §101.P1). White on the
/// dark modes' light accents (e.g. sport/dark lime) measured 1.2-2.6:1,
/// below the 3:1 non-text minimum.
Color markerIconColor(Color accent) {
  double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  return ratio(accent, Colors.white) >= ratio(accent, markerDarkInk)
      ? Colors.white
      : markerDarkInk;
}
