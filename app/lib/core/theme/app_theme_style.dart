import 'package:flutter/material.dart';

/// The app has exactly two themes (critique 2026-10-14 §6/§14: two themes,
/// not 28 combinations): [calmingLight], the sage-on-cream default every new
/// install starts on, and [carbonMonoDark], the lime-on-carbon flagship whose
/// accent stays visible over the bright OSM map at night. A rider picks only
/// Light, Dark or System (see `theme_style_provider.dart`).
///
/// Registered on [ThemeData.extensions] by `AppTheme.build` and read with
/// `context.palette` (see `app_theme_context.dart`). Because it travels
/// through the widget tree like any other theme value, a widget that reads it
/// in `build` is rebuilt when the rider changes appearance — nothing has to
/// be remounted, and no widget keeps stale colors.
class AppColorPalette extends ThemeExtension<AppColorPalette> {
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

  /// Whether this palette sits on a dark base. Drives the Material
  /// `ThemeData` brightness, the `ColorScheme` variant and the status-bar
  /// icon color in `app_theme.dart`, and which app mark `AppLogo` shows.
  final bool isDark;

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
    required this.isDark,
  });

  @override
  AppColorPalette copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? surfaceVariant,
    Color? ink,
    Color? onInk,
    Color? onInkMuted,
    Color? primary,
    Color? primaryHighlight,
    Color? primaryDark,
    Color? secondary,
    Color? secondaryLight,
    Color? attention,
    Color? success,
    Color? warning,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? overlayDark,
    Color? shimmerBase,
    Color? shimmerHighlight,
    bool? isDark,
  }) =>
      AppColorPalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        ink: ink ?? this.ink,
        onInk: onInk ?? this.onInk,
        onInkMuted: onInkMuted ?? this.onInkMuted,
        primary: primary ?? this.primary,
        primaryHighlight: primaryHighlight ?? this.primaryHighlight,
        primaryDark: primaryDark ?? this.primaryDark,
        secondary: secondary ?? this.secondary,
        secondaryLight: secondaryLight ?? this.secondaryLight,
        attention: attention ?? this.attention,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        overlayDark: overlayDark ?? this.overlayDark,
        shimmerBase: shimmerBase ?? this.shimmerBase,
        shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
        isDark: isDark ?? this.isDark,
      );

  /// Colors cross-fade while `MaterialApp` animates a theme change; [isDark]
  /// is not interpolable, so it flips at the halfway point.
  @override
  AppColorPalette lerp(ThemeExtension<AppColorPalette>? other, double t) {
    if (other is! AppColorPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColorPalette(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      border: c(border, other.border),
      surfaceVariant: c(surfaceVariant, other.surfaceVariant),
      ink: c(ink, other.ink),
      onInk: c(onInk, other.onInk),
      onInkMuted: c(onInkMuted, other.onInkMuted),
      primary: c(primary, other.primary),
      primaryHighlight: c(primaryHighlight, other.primaryHighlight),
      primaryDark: c(primaryDark, other.primaryDark),
      secondary: c(secondary, other.secondary),
      secondaryLight: c(secondaryLight, other.secondaryLight),
      attention: c(attention, other.attention),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      overlayDark: c(overlayDark, other.overlayDark),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  /// The light theme. Warm cream, sage primary, tan secondary.
  static const AppColorPalette calmingLight = AppColorPalette(
    background: Color(0xFFF8F5EF),
    surface: Color(0xFFFEFBF8),
    border: Color(0xFFE1DDD8),
    surfaceVariant: Color(0xFFEEEBE5),
    ink: Color(0xFF2B2823),
    onInk: Color(0xFFF8F5EF),
    onInkMuted: Color(0xFFB1ADA7),
    // Darker sage so white button text (4.97:1) and sage link text on the
    // cream background (4.56:1) clear WCAG AA. The old, lighter #84A98B only
    // reached 2.62:1, so it now lives on as the non-text highlight fill.
    // Text and status tokens below are tuned to AA the same way (2026-10-22);
    // test/core/theme/palette_contrast_test.dart keeps them there.
    primary: Color(0xFF517959),
    primaryHighlight: Color(0xFF84A98B),
    primaryDark: Color(0xFF3D5E45),
    secondary: Color(0xFFBD8D65),
    secondaryLight: Color(0xFFDBB597),
    attention: Color(0xFF7E5635),
    success: Color(0xFF416849),
    warning: Color(0xFF7F5727),
    danger: Color(0xFFA33A36),
    textPrimary: Color(0xFF2B2823),
    textSecondary: Color(0xFF66635D),
    textTertiary: Color(0xFF6C6964),
    overlayDark: Color(0xCC24211C),
    shimmerBase: Color(0xFFE7E4DF),
    shimmerHighlight: Color(0xFFF5F1EC),
    isDark: false,
  );

  /// The dark theme. Instrument-panel black, lime primary, magenta secondary.
  static const AppColorPalette carbonMonoDark = AppColorPalette(
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF161616),
    border: Color(0xFF393939),
    surfaceVariant: Color(0xFF262626),
    ink: Color(0xFF000000),
    onInk: Color(0xFFF4F4F4),
    onInkMuted: Color(0xFF757575),
    primary: Color(0xFFC8FF3D), // lime
    primaryHighlight: Color(0xFFE4FF8F),
    primaryDark: Color(0xFF9FCC1F),
    secondary: Color(0xFFD633FF), // magenta
    secondaryLight: Color(0xFFE88CFF),
    attention: Color(0xFFFF7A45),
    success: Color(0xFF42BE65),
    warning: Color(0xFFFF7A45),
    danger: Color(0xFFFA5A62),
    textPrimary: Color(0xFFF4F4F4),
    textSecondary: Color(0xFFA8A8A8),
    textTertiary: Color(0xFF8D8D8D),
    overlayDark: Color(0xCC000000),
    shimmerBase: Color(0xFF262626),
    shimmerHighlight: Color(0xFF393939),
    isDark: true,
  );

  static AppColorPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? carbonMonoDark : calmingLight;
}
