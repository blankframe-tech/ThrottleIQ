import 'app_theme_style.dart';

/// One immutable set of *shape* tokens — corner radii, rule weights and the
/// handful of control metrics that read as part of a skin's silhouette.
///
/// This is the third axis of a skin, alongside [AppColorPalette] (color) and
/// [AppTypography] (type). It exists because shape used to be shared by every
/// skin but Retro: `AppTheme.build` computed `isTerminal ? 0 : shared` and
/// every other skin took the same near-zero "instrument panel" radii, so nine
/// visually distinct directions all had identical corners. A palette swap alone
/// can't carry a direction like "Positive Vibes" (a bright health-app look)
/// away from one like "Analyst Blue" (a monitoring console) — the corner radius
/// is doing as much of that work as the accent hue is.
///
/// Applied through [AppDimensions] the same way palettes are applied through
/// [AppColors] — a static facade swapped in one place (see
/// `theme_style_provider.dart`) so the ~96 existing `AppDimensions.radius*`
/// call sites pick up the active skin's shape without any call-site churn.
///
/// What this deliberately does **not** contain: anything that would move,
/// add, or remove a widget. No skin changes the layout hierarchy — the same
/// screens render the same widgets in the same order on every skin. These
/// tokens only change how those widgets are drawn and how much room they take.
class AppShapeProfile {
  /// Corner radii, smallest to largest. [radiusFull] is the "pill" token —
  /// used for chips, progress bars and badges, where a boxy skin wants a
  /// barely-softened rectangle and a rounded one wants a true stadium.
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusFull;

  /// Hairline weight for card edges and outlined surfaces.
  final double outlineWidth;

  /// Weight for outlines that are carrying emphasis rather than just
  /// separating two surfaces — the secondary-action button border.
  final double emphasisOutlineWidth;

  /// Minimum height for the primary/secondary button pair. Part of the
  /// silhouette, not the hierarchy: a rounder skin reads better with a
  /// slightly taller, softer control, a boxy one with a tighter one.
  final double controlHeight;

  /// Content padding inside text fields, which has to grow with the corner
  /// radius or the text starts to crowd the curve.
  final double fieldPaddingH;
  final double fieldPaddingV;

  const AppShapeProfile({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusFull,
    required this.outlineWidth,
    required this.emphasisOutlineWidth,
    required this.controlHeight,
    required this.fieldPaddingH,
    required this.fieldPaddingV,
  });

  /// Sharp, near-zero-radius instrument-panel edges — the shape every skin
  /// shared before profiles existed, kept verbatim so the skins that stay boxy
  /// are pixel-identical to what riders already have.
  static const AppShapeProfile boxy = AppShapeProfile(
    radiusSm: 2,
    radiusMd: 2,
    radiusLg: 4,
    radiusXl: 6,
    radiusFull: 4,
    outlineWidth: 1,
    emphasisOutlineWidth: 1.5,
    controlHeight: 52,
    fieldPaddingH: 16,
    fieldPaddingV: 14,
  );

  /// Soft, friendly corners with true pills for chips and bars, plus a little
  /// more room inside controls so the curve has something to curve around.
  ///
  /// The step up from [boxy] is deliberately large (2→10 at the medium token,
  /// 6→20 at the extra-large): a couple of pixels reads as a rendering
  /// artifact rather than as a different skin, which is the whole failure this
  /// profile exists to fix.
  static const AppShapeProfile rounded = AppShapeProfile(
    radiusSm: 8,
    radiusMd: 10,
    radiusLg: 16,
    radiusXl: 20,
    // A radius larger than any half-height it's applied to; Flutter clamps it,
    // so this is the standard way to spell "stadium" for a Container whose
    // height isn't known at the call site.
    radiusFull: 999,
    outlineWidth: 1,
    emphasisOutlineWidth: 1.5,
    controlHeight: 54,
    fieldPaddingH: 18,
    fieldPaddingV: 16,
  );

  /// Retro's old-terminal shape: every corner square, every rule doubled.
  ///
  /// Kept as its own profile rather than folded into [boxy] because they are
  /// not the same intent — boxy is a tight radius, this is the *absence* of
  /// one, and it comes with the heavy black rule that
  /// [AppColorPalette.retro]'s ink-strength `border` is drawn with. A rounded
  /// card with a 2px black rule around it reads as a mistake rather than a
  /// style, which is why the two travel together.
  static const AppShapeProfile terminal = AppShapeProfile(
    radiusSm: 0,
    radiusMd: 0,
    radiusLg: 0,
    radiusXl: 0,
    radiusFull: 0,
    outlineWidth: 2,
    emphasisOutlineWidth: 2,
    controlHeight: 52,
    fieldPaddingH: 16,
    fieldPaddingV: 14,
  );

  /// Exhaustive by design — a `switch` with no `default`, so adding a member
  /// to [AppThemeStyle] without assigning it a shape is a compile error rather
  /// than a skin that silently inherits whichever profile is listed first.
  /// Same contract as [AppColorPalette.forStyle].
  ///
  /// The split is by what each direction is *for*, not by brightness:
  ///
  /// - Rounded: Positive Vibes (health-app energy), Calming (wellness), Trail
  ///   Social (a social feed). Soft corners are the vocabulary all three of
  ///   those product categories already speak.
  /// - Boxy: Carbon Mono, Nocturne, Analyst Blue, Genesis, Editorial —
  ///   dashboard, console, premium and print directions, where a sharp edge is
  ///   part of the identity and rounding it off would flatten five distinct
  ///   skins toward the same soft default.
  /// - Terminal: Retro only.
  static AppShapeProfile forStyle(AppThemeStyle style) => switch (style) {
        AppThemeStyle.carbonMono => boxy,
        AppThemeStyle.editorial => boxy,
        AppThemeStyle.nocturne => boxy,
        AppThemeStyle.trailSocial => rounded,
        AppThemeStyle.calming => rounded,
        AppThemeStyle.positiveVibes => rounded,
        AppThemeStyle.retro => terminal,
        AppThemeStyle.analystBlue => boxy,
        AppThemeStyle.genesis => boxy,
      };
}
