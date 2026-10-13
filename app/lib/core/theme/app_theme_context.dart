import 'package:flutter/material.dart';

import 'app_shape_profile.dart';
import 'app_theme_style.dart';
import 'theme_style_provider.dart';

/// Reads the active design tokens off the widget tree.
///
/// `context.palette` and `context.shape` replace the mutable static facades
/// (`AppColors`, `AppDimensions`) this app used to read from. The difference
/// is the whole point: they resolve through `Theme.of`, so they register the
/// calling widget as a dependent and it is rebuilt when the appearance
/// changes. A static read sits outside that dependency graph, which is why the
/// old code had to key `MaterialApp` on the appearance and remount the entire
/// app to make a theme switch visible.
///
/// Call these from `build` (or a builder). Reading them in `initState` throws,
/// and caching the result in a field freezes it — both are the old bug again.
extension AppThemeContext on BuildContext {
  /// Color tokens for the current appearance.
  AppColorPalette get palette =>
      Theme.of(this).extension<AppColorPalette>() ?? _fallbackPalette;

  /// Shape tokens (radii, rule weights, control metrics) for the current
  /// appearance.
  AppShapeProfile get shape =>
      Theme.of(this).extension<AppShapeProfile>() ?? _fallbackShape;
}

// A tree built without `AppTheme.build` — a widget test that pumps a bare
// `MaterialApp`, say — has no extensions registered. Fall back to the default
// appearance rather than throwing, so such a tree still renders. The real app
// always registers both (see `AppTheme.build`).
final AppColorPalette _fallbackPalette = AppColorPalette.forMode(
  AppAppearance.defaultAppearance.colorMode,
  AppAppearance.defaultAppearance.brightness,
);
final AppShapeProfile _fallbackShape =
    AppShapeProfile.forVibe(AppAppearance.defaultAppearance.shapeVibe);
