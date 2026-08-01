import 'package:flutter/material.dart';

/// The two selectable design languages. Both share the same sharp,
/// near-zero-radius shape system and IBM Plex typography — only the color
/// palette (and app logo) differ.
enum AppThemeStyle { carbonMono, editorial }

/// One immutable set of color tokens, matching the field names historically
/// exposed by `AppColors` so both palettes can be swapped in behind it
/// without touching any of the ~565 call sites across the app.
class AppColorPalette {
  final Color background;
  final Color surface;
  final Color border;
  final Color surfaceVariant;

  final Color ink;
  final Color onInk;
  final Color onInkMuted;

  final Color primary;
  final Color primaryHighlight;
  final Color primaryDark;

  final Color secondary;
  final Color secondaryLight;
  final Color attention;

  final Color success;
  final Color warning;
  final Color danger;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color overlayDark;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColorPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.surfaceVariant,
    required this.ink,
    required this.onInk,
    required this.onInkMuted,
    required this.primary,
    required this.primaryHighlight,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryLight,
    required this.attention,
    required this.success,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.overlayDark,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// "Carbon Mono" — dark instrument-panel base, lime primary, purple/magenta
  /// secondary. The app's primary, default design language.
  static const AppColorPalette carbonMono = AppColorPalette(
    background: Color(0xFF0D0D0D), // carbon black
    surface: Color(0xFF161616), // card / raised panel
    border: Color(0xFF393939), // hairline
    surfaceVariant: Color(0xFF262626), // subtle fill
    ink: Color(0xFF000000),
    onInk: Color(0xFFF4F4F4), // near-white text on ink
    onInkMuted: Color(0xFF6F6F6F),
    primary: Color(0xFFC8FF3D), // lime
    primaryHighlight: Color(0xFFE4FF8F),
    primaryDark: Color(0xFF9FCC1F),
    secondary: Color(0xFFD633FF), // magenta
    secondaryLight: Color(0xFFE88CFF),
    attention: Color(0xFFFF7A45), // amber-orange caution
    success: Color(0xFF42BE65),
    warning: Color(0xFFFF7A45),
    danger: Color(0xFFFA4D56),
    textPrimary: Color(0xFFF4F4F4),
    textSecondary: Color(0xFFA8A8A8),
    textTertiary: Color(0xFF6F6F6F),
    overlayDark: Color(0xCC000000),
    shimmerBase: Color(0xFF262626),
    shimmerHighlight: Color(0xFF393939),
  );

  /// "Editorial" — light warm paper base, ink text, blue primary and orange
  /// attention accent. The app's opt-in alternate palette.
  static const AppColorPalette editorial = AppColorPalette(
    background: Color(0xFFF4F1EC), // cream paper
    surface: Color(0xFFFAF9F6), // card / raised paper
    border: Color(0xFFE8E5DF), // warm hairline
    surfaceVariant: Color(0xFFF0EEE9), // subtle fill
    ink: Color(0xFF121212),
    onInk: Color(0xFFF4F1EC), // paper text on ink
    onInkMuted: Color(0xFFB0B0B0),
    primary: Color(0xFF3B6CF6), // blue
    primaryHighlight: Color(0xFF6B90F8),
    primaryDark: Color(0xFF2952C8),
    secondary: Color(0xFFF2703C), // orange
    secondaryLight: Color(0xFFF58C5F),
    attention: Color(0xFFF2703C),
    success: Color(0xFF1AA568),
    warning: Color(0xFFF2703C),
    danger: Color(0xFFE5484D),
    textPrimary: Color(0xFF141414),
    textSecondary: Color(0xFF6B6B6B),
    textTertiary: Color(0xFF9A9A9A),
    overlayDark: Color(0xCC141414),
    shimmerBase: Color(0xFFE8E5DF),
    shimmerHighlight: Color(0xFFF0EEE9),
  );

  static AppColorPalette forStyle(AppThemeStyle style) =>
      style == AppThemeStyle.carbonMono ? carbonMono : editorial;
}
