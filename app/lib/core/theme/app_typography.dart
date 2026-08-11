import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'app_theme_style.dart';

/// Runtime-swappable display typeface, applied the same way [AppColors] swaps
/// palettes — see `theme_style_provider.dart`.
///
/// Every skin but one shares Space Grotesk for headings and big numbers, on
/// the same reasoning that keeps the shape system shared: a skin is a palette,
/// not a rebrand. Retro is the exception. It's the one direction whose whole
/// identity is a monospace terminal, and a proportional display face on top of
/// square corners and hard black rules reads as an unfinished theme rather
/// than a stylistic choice — so it gets IBM Plex Mono, which the app already
/// ships for the body/heading pairing.
///
/// Kept as a static facade rather than a `Theme.of(context)` extension for the
/// same reason [AppColors] is: `display()` is called from several hundred
/// places, many of them outside a build method, and threading a context
/// through all of them buys nothing here.
class AppTypography {
  AppTypography._();

  static AppThemeStyle _style = AppThemeStyle.carbonMono;

  static void applyStyle(AppThemeStyle style) => _style = style;

  /// Whether the current skin sets display type in a monospace face.
  static bool get isMono => _style == AppThemeStyle.retro;

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
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
    double? height,
  }) {
    final resolved = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
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
}
