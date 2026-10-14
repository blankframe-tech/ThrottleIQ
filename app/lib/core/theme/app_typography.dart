import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_context.dart';

/// The app's display typeface (Space Grotesk) and the live-ride cockpit type
/// styles. These take a [BuildContext] so the color follows the active theme.
class AppTypography {
  AppTypography._();

  /// Bundled Bengali fallback (see pubspec.yaml) for every text style this
  /// app hands out. Neither Space Grotesk, IBM Plex Sans, nor IBM Plex Mono
  /// ship Bengali glyphs, so without this, Bangla text silently rendered in
  /// whatever face the platform happened to substitute. Appended rather than
  /// primary: it's only ever consulted for codepoints the primary face
  /// doesn't cover, so Latin text is untouched.
  static const List<String> bengaliFallback = ['NotoSansBengali'];

  /// Display text — headings, big numbers, anything that should read as the
  /// app's voice rather than as body copy.
  static TextStyle display(
    BuildContext context,
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
    double? height,
  }) {
    final styled = GoogleFonts.spaceGrotesk(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? context.palette.textPrimary,
        letterSpacing: letterSpacing,
        height: height,
      ),
    );
    return styled.copyWith(fontFamilyFallback: bengaliFallback);
  }

  /// Cockpit type floor for the live-ride screens, read at a glance from a
  /// handlebar mount: labels never below [cockpitLabelSize], values never
  /// below [cockpitValueSize] (grill §3.1.2). Use these rather than
  /// literals so the floor can't quietly drift back down one widget at a time.
  static const double cockpitLabelSize = 14;
  static const double cockpitValueSize = 20;

  /// Small caption under/next to a live value ("Distance", "BRAKE").
  static TextStyle cockpitLabel(
    BuildContext context, {
    Color? color,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontSize: cockpitLabelSize,
        fontWeight: weight,
        color: color ?? context.palette.textSecondary,
        letterSpacing: letterSpacing,
        fontFamilyFallback: bengaliFallback,
      );

  /// A live secondary value (distance, average speed, g-force). The primary
  /// speed readout is far larger and keeps its own `display(64)`.
  static TextStyle cockpitValue(
    BuildContext context, {
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) =>
      display(context, cockpitValueSize,
          weight: weight, color: color, letterSpacing: 0);
}
