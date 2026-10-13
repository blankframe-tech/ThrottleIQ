/// Skin-independent spacing and chrome metrics.
///
/// Spacing is *not* part of a skin: it sets where things sit relative to each
/// other, and a skin changes how the app looks, not its layout. So these stay
/// plain constants. The skin-dependent shape tokens (corner radii, rule
/// weights, control metrics) live on `AppShapeProfile` and are read with
/// `context.shape` — see `core/theme/app_theme_context.dart`.
class AppDimensions {
  AppDimensions._();

  static const double paddingSm = 8.0;
  static const double paddingMd = 16.0;
  static const double paddingLg = 24.0;
  static const double paddingXl = 32.0;

  static const double bottomNavHeight = 72.0;
  static const double appBarHeight = 64.0;
}
