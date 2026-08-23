/// Which gesture the Record screen's start control uses.
///
/// Not a cosmetic choice — the two are different widgets with different
/// affordances — but it belongs with the shape tokens because the reason to
/// pick one over the other is the vibe's silhouette. See [AppShapeProfile]'s
/// note on why this is the one exception to "shape never changes a widget".
enum StartControlStyle {
  /// Full-width "slide to start" track. The historical control, and the right
  /// one for Boxy, whose whole vocabulary is rectangles.
  slide,

  /// Circular press-and-hold ring: hold the button and a progress arc sweeps
  /// the circumference; release early and it unwinds.
  holdRing,
}

/// The two selectable shape "vibes" — corner geometry, independent of color.
///
/// A rider picks this separately from [AppColorMode]: any color mode can be
/// Boxy or Curvy. This is what makes "sharp dark like Nothing" and "rounded
/// light like iOS" both reachable from the same seven palettes, instead of
/// baking a fixed shape into each named skin.
enum AppShapeVibe { boxy, curvy }

/// One immutable set of *shape* tokens — corner radii, rule weights and the
/// handful of control metrics that read as part of a vibe's silhouette.
///
/// This is the second axis of a look, alongside [AppColorMode] (color) — see
/// that enum's doc comment for how the two combine. Applied through
/// [AppDimensions] the same way palettes are applied through [AppColors] — a
/// static facade swapped in one place (see `theme_style_provider.dart`) so
/// the ~96 existing `AppDimensions.radius*` call sites pick up the active
/// vibe without any call-site churn.
///
/// What this deliberately does **not** contain: anything that would move,
/// add, or remove a widget (with the one exception below). No vibe changes
/// the layout hierarchy — the same screens render the same widgets in the
/// same order either way. These tokens only change how those widgets are
/// drawn and how much room they take.
///
/// [startControl] is the one deliberate exception, and it is scoped to a
/// single control. A slide-to-start bar is a *rectangle* gesture — its
/// affordance is the width it travels across — and on Curvy it was the last
/// hard-edged full-width slab on an otherwise soft screen. Swapping it for a
/// press-and-hold ring on Curvy is the same trade the radii make elsewhere,
/// just at the scale where shape and interaction stop being separable.
class AppShapeProfile {
  /// Corner radii, smallest to largest. [radiusFull] is the "pill" token —
  /// used for chips, progress bars and badges, where Boxy wants a
  /// barely-softened rectangle and Curvy wants a true stadium.
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
  /// silhouette, not the hierarchy: Curvy reads better with a slightly
  /// taller, softer control, Boxy with a tighter one.
  final double controlHeight;

  /// Content padding inside text fields, which has to grow with the corner
  /// radius or the text starts to crowd the curve.
  final double fieldPaddingH;
  final double fieldPaddingV;

  /// Which start control the Record screen renders. See [StartControlStyle].
  final StartControlStyle startControl;

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
    this.startControl = StartControlStyle.slide,
  });

  /// Sharp, near-zero-radius instrument-panel edges — the "like Nothing"
  /// vibe. Values kept verbatim from the app's original (and only, pre-vibe)
  /// shape, so Boxy is pixel-identical to what riders already had.
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
  /// more room inside controls so the curve has something to curve around —
  /// the "for iPhone" vibe, matching iOS's own rounded-rect language.
  ///
  /// The step up from [boxy] is deliberately large (2→10 at the medium token,
  /// 6→20 at the extra-large): a couple of pixels reads as a rendering
  /// artifact rather than as a different vibe, which is the whole failure
  /// this profile exists to fix.
  static const AppShapeProfile curvy = AppShapeProfile(
    radiusSm: 8,
    radiusMd: 10,
    radiusLg: 16,
    radiusXl: 20,
    // A radius larger than any half-height it's applied to; Flutter clamps
    // it, so this is the standard way to spell "stadium" for a Container
    // whose height isn't known at the call site.
    radiusFull: 999,
    outlineWidth: 1,
    emphasisOutlineWidth: 1.5,
    controlHeight: 54,
    fieldPaddingH: 18,
    fieldPaddingV: 16,
    // The full-width slide track was the one hard rectangle left on a
    // rounded screen, and its affordance is horizontal travel — there is no
    // rounded version of it that still reads as "slide". A hold-to-start
    // ring is the circular equivalent of the same deliberate, non-accidental
    // gesture.
    startControl: StartControlStyle.holdRing,
  );

  /// Exhaustive by design — a `switch` with no `default`, so adding a member
  /// to [AppShapeVibe] without assigning it a profile is a compile error.
  static AppShapeProfile forVibe(AppShapeVibe vibe) => switch (vibe) {
        AppShapeVibe.boxy => boxy,
        AppShapeVibe.curvy => curvy,
      };
}
