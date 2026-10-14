import 'package:flutter/material.dart';

/// The app's shape tokens: corner radii, rule weights and the control
/// metrics that go with them. There is one profile, [curvy]; the Boxy
/// alternative was cut with the other appearance combinations (critique
/// 2026-10-14 §14). Registered on [ThemeData.extensions] by `AppTheme.build`,
/// next to `AppColorPalette`, and read with `context.shape`.
class AppShapeProfile extends ThemeExtension<AppShapeProfile> {
  /// Corner radii, smallest to largest. [radiusFull] is the "pill" token,
  /// used for chips, progress bars and badges.
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

  /// Minimum height for the primary/secondary button pair.
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

  @override
  AppShapeProfile copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    double? outlineWidth,
    double? emphasisOutlineWidth,
    double? controlHeight,
    double? fieldPaddingH,
    double? fieldPaddingV,
  }) =>
      AppShapeProfile(
        radiusSm: radiusSm ?? this.radiusSm,
        radiusMd: radiusMd ?? this.radiusMd,
        radiusLg: radiusLg ?? this.radiusLg,
        radiusXl: radiusXl ?? this.radiusXl,
        radiusFull: radiusFull ?? this.radiusFull,
        outlineWidth: outlineWidth ?? this.outlineWidth,
        emphasisOutlineWidth: emphasisOutlineWidth ?? this.emphasisOutlineWidth,
        controlHeight: controlHeight ?? this.controlHeight,
        fieldPaddingH: fieldPaddingH ?? this.fieldPaddingH,
        fieldPaddingV: fieldPaddingV ?? this.fieldPaddingV,
      );

  /// Shape does not tween ([radiusFull] is 999, so interpolating would sweep
  /// pills through absurd radii); it flips at the halfway point.
  @override
  AppShapeProfile lerp(ThemeExtension<AppShapeProfile>? other, double t) =>
      other is AppShapeProfile && t >= 0.5 ? other : this;

  /// Soft corners with true pills for chips and bars.
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
  );
}
