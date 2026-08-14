import '../theme/app_shape_profile.dart';

/// Runtime-swappable shape tokens for ThrottleIQ.
///
/// Backed by an [AppShapeProfile] (boxy by default, matching Carbon Mono) that
/// [apply] swaps out when the rider changes skin — the same static-facade
/// pattern [AppColors] uses for palettes and [AppTypography] uses for the
/// display face, and applied from the same place so a skin can never end up
/// half-applied. See `theme_style_provider.dart`.
///
/// The radii were `static const` and shared by every skin but Retro until
/// per-skin shape landed. Field names are kept stable so the ~96 references
/// across the app pick up whichever profile is current without call-site churn.
/// Because they are now getters rather than `static const`, any `const`
/// expression that embedded one (e.g. `const BorderRadius.all(...)`) has to
/// drop the `const` keyword.
///
/// Spacing is *not* part of a skin. `padding*` and the two chrome heights stay
/// `static const`: they set where things sit relative to each other, and a skin
/// changes how the app looks, not its layout.
class AppDimensions {
  AppDimensions._();

  static AppShapeProfile _current = AppShapeProfile.boxy;

  static void apply(AppShapeProfile profile) {
    _current = profile;
  }

  /// The active profile. Exposed for widgets that need a shape token this
  /// facade doesn't name individually.
  static AppShapeProfile get shape => _current;

  // Corner radii — sharp near-zero instrument-panel edges on the boxy skins,
  // soft corners and true pills on the rounded ones, square on Retro.
  static double get radiusSm => _current.radiusSm;
  static double get radiusMd => _current.radiusMd;
  static double get radiusLg => _current.radiusLg;
  static double get radiusXl => _current.radiusXl;
  static double get radiusFull => _current.radiusFull;

  // Rule weights and control metrics — read by `app_theme.dart` when it builds
  // the shared card/field/button themes.
  static double get outlineWidth => _current.outlineWidth;
  static double get emphasisOutlineWidth => _current.emphasisOutlineWidth;
  static double get controlHeight => _current.controlHeight;
  static double get fieldPaddingH => _current.fieldPaddingH;
  static double get fieldPaddingV => _current.fieldPaddingV;

  // Spacing and chrome — skin-independent, see the class doc.
  static const double paddingSm = 8.0;
  static const double paddingMd = 16.0;
  static const double paddingLg = 24.0;
  static const double paddingXl = 32.0;

  static const double bottomNavHeight = 72.0;
  static const double appBarHeight = 64.0;
}
