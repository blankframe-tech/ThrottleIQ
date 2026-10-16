import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_context.dart';
import '../domain/calculators/speed_segments.dart';

/// The colour a speed band is drawn in on route maps and their legend.
/// Shared so the ride summary and the full-screen map always agree.
extension SpeedBandStyle on SpeedBand {
  Color color(BuildContext context) {
    final palette = context.palette;
    return switch (this) {
      SpeedBand.idle => palette.textTertiary,
      SpeedBand.normal => palette.success,
      SpeedBand.brisk => palette.warning,
      SpeedBand.hard => palette.danger,
    };
  }
}
