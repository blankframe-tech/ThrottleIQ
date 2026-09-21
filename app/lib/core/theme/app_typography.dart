import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_context.dart';

/// The app's display typeface and the live-ride cockpit type styles.
///
/// Every skin but one shares Space Grotesk for headings and big numbers, on
/// the same reasoning that keeps the shape system shared: a skin is a palette,
/// not a rebrand. Retro is the exception. It's the one direction whose whole
/// identity is a monospace terminal, and a proportional display face on top of
/// square corners and hard black rules reads as an unfinished theme rather
/// than a stylistic choice — so it gets IBM Plex Mono, which the app already
/// ships for the body/heading pairing.
///
/// Which face applies is read off the theme (`AppColorPalette.monoDisplay`),
/// which is why these take a [BuildContext]: the style is rebuilt with the
/// widget when the rider changes appearance.
class AppTypography {
  AppTypography._();

  /// Bundled Bengali fallback (see pubspec.yaml) for every text style this
  /// app hands out. Neither Space Grotesk, IBM Plex Sans, nor IBM Plex Mono
  /// ship Bengali glyphs, so without this, Bangla text silently rendered in
  /// whatever face the platform happened to substitute — matching neither
  /// the skin's type nor, across platforms, itself. Appended rather than
  /// primary: it's only ever consulted for codepoints the skin's own face
  /// doesn't cover, so Latin text is untouched.
  static const List<String> bengaliFallback = ['NotoSansBengali'];

  /// Display text — headings, big numbers, anything that should read as the
  /// skin's voice rather than as body copy.
  static TextStyle display(
    BuildContext context,
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
    double? height,
  }) {
    final palette = context.palette;
    final isMono = palette.monoDisplay;
    final resolved = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? palette.textPrimary,
      // Negative tracking tightens a proportional face; on a monospace one it
      // fights the fixed advance width and reads as cramped. Mono holds at
      // its natural spacing unless a caller asked for extra.
      letterSpacing: isMono ? (letterSpacing > 0 ? letterSpacing : 0) : letterSpacing,
      height: height,
    );
    final styled = isMono
        ? GoogleFonts.ibmPlexMono(textStyle: resolved)
        : GoogleFonts.spaceGrotesk(textStyle: resolved);
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
