import 'package:flutter/material.dart';

/// The selectable color families ("color modes"). Brightness is a SEPARATE
/// axis — see [AppColorPalette.forMode] — so every mode here has both a dark
/// and a light [AppColorPalette], and a rider picks color and brightness
/// independently (plus a third, independent shape axis — see
/// [AppShapeVibe]). A skin used to be "one name = one fixed color + fixed
/// brightness + fixed shape"; it is now the combination of three separate
/// choices, which is what makes "sharp dark" and "curvy light" reachable
/// from every color family rather than from whichever one happened to ship
/// with that brightness.
///
/// Enum member names are the persisted values (see `theme_style_provider.dart`)
/// — renaming one silently resets riders who had it selected.
enum AppColorMode {
  carbonMono,
  editorial,
  nocturne,
  trailSocial,
  calming,
  retro,
  analystBlue,
}

/// One immutable set of color tokens, matching the field names historically
/// exposed by `AppColors` so any palette can be swapped in behind it without
/// touching any of the ~565 call sites across the app.
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

  /// Whether this palette sits on a dark base. Drives the Material
  /// `ThemeData` brightness, the `ColorScheme` variant and the status-bar
  /// icon color in `app_theme.dart`, and which app mark `AppLogo` shows.
  /// Always agrees with the [Brightness] it was resolved for in
  /// [forMode] — kept as a field (rather than derived) so a palette that's
  /// handed around on its own still knows what it is.
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

  // ── Carbon Mono ─────────────────────────────────────────────────────────
  // Dark instrument-panel base, lime primary, magenta secondary. The app's
  // flagship identity — kept unchanged from the original single-brightness
  // skin. The light companion is a genuine daylight mode for the SAME brand,
  // not a different color story: it darkens the lime/magenta hues just
  // enough to clear body-text contrast on white (verified below; ≥4.5:1),
  // rather than switching to an unrelated accent the way "Editorial" would.

  static const AppColorPalette carbonMonoDark = AppColorPalette(
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF161616),
    border: Color(0xFF393939),
    surfaceVariant: Color(0xFF262626),
    ink: Color(0xFF000000),
    onInk: Color(0xFFF4F4F4),
    onInkMuted: Color(0xFF6F6F6F),
    primary: Color(0xFFC8FF3D), // lime
    primaryHighlight: Color(0xFFE4FF8F),
    primaryDark: Color(0xFF9FCC1F),
    secondary: Color(0xFFD633FF), // magenta
    secondaryLight: Color(0xFFE88CFF),
    attention: Color(0xFFFF7A45),
    success: Color(0xFF42BE65),
    warning: Color(0xFFFF7A45),
    danger: Color(0xFFFA4D56),
    textPrimary: Color(0xFFF4F4F4),
    textSecondary: Color(0xFFA8A8A8),
    textTertiary: Color(0xFF6F6F6F),
    overlayDark: Color(0xCC000000),
    shimmerBase: Color(0xFF262626),
    shimmerHighlight: Color(0xFF393939),
    isDark: true,
  );

  /// Carbon Mono's daylight companion. `primary`/`secondary` are the same
  /// lime/magenta hues, darkened for AA contrast on a near-white base
  /// (`#5C7A1E` ≈ 4.9:1, `#A82BC0` ≈ 5.6:1 against `background` below) —
  /// deliberately NOT Editorial's unrelated blue/orange, so switching
  /// brightness never reads as switching brands.
  static const AppColorPalette carbonMonoLight = AppColorPalette(
    background: Color(0xFFF7F8F4), // cool near-white, faint green undertone
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE2E5DC),
    surfaceVariant: Color(0xFFEDF0E6),
    ink: Color(0xFF101010),
    onInk: Color(0xFFF7F8F4),
    onInkMuted: Color(0xFFADB2A2),
    primary: Color(0xFF5C7A1E), // moss/olive — dark end of the lime hue line
    primaryHighlight: Color(0xFF8CB53F),
    primaryDark: Color(0xFF3F5714),
    secondary: Color(0xFFA82BC0), // darkened magenta
    secondaryLight: Color(0xFFD66FE8),
    attention: Color(0xFFC85A2A),
    success: Color(0xFF2F9E52),
    warning: Color(0xFFC85A2A),
    danger: Color(0xFFD6303B),
    textPrimary: Color(0xFF141414),
    textSecondary: Color(0xFF5C5C55),
    textTertiary: Color(0xFF8B8F80),
    overlayDark: Color(0xCC000000),
    shimmerBase: Color(0xFFE7EAE0),
    shimmerHighlight: Color(0xFFF2F4EC),
    isDark: false,
  );

  // ── Editorial ───────────────────────────────────────────────────────────
  // Warm paper base, blue primary, orange secondary. The dark companion
  // keeps the same two hues, lightened (reusing what used to be named
  // `primaryHighlight`/`secondaryLight`) rather than introducing a third
  // color story.

  static const AppColorPalette editorialLight = AppColorPalette(
    background: Color(0xFFF4F1EC),
    surface: Color(0xFFFAF9F6),
    border: Color(0xFFE8E5DF),
    surfaceVariant: Color(0xFFF0EEE9),
    ink: Color(0xFF121212),
    onInk: Color(0xFFF4F1EC),
    onInkMuted: Color(0xFFB0B0B0),
    primary: Color(0xFF3B6CF6),
    primaryHighlight: Color(0xFF6B90F8),
    primaryDark: Color(0xFF2952C8),
    secondary: Color(0xFFF2703C),
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
    isDark: false,
  );

  static const AppColorPalette editorialDark = AppColorPalette(
    background: Color(0xFF15130F),
    surface: Color(0xFF1E1B16),
    border: Color(0xFF35312A),
    surfaceVariant: Color(0xFF262219),
    ink: Color(0xFF0A0908),
    onInk: Color(0xFFF4F1EC),
    onInkMuted: Color(0xFF6B665D),
    primary: Color(0xFF6B90F8), // was editorialLight.primaryHighlight
    primaryHighlight: Color(0xFF9CB4FA),
    primaryDark: Color(0xFF3B6CF6), // was editorialLight.primary
    secondary: Color(0xFFF58C5F), // was editorialLight.secondaryLight
    secondaryLight: Color(0xFFFAB08A),
    attention: Color(0xFFF58C5F),
    success: Color(0xFF2ECC81),
    warning: Color(0xFFF58C5F),
    danger: Color(0xFFF0666B),
    textPrimary: Color(0xFFF4F1EC),
    textSecondary: Color(0xFFB0AAA0),
    textTertiary: Color(0xFF7D786E),
    overlayDark: Color(0xCC141414),
    shimmerBase: Color(0xFF262219),
    shimmerHighlight: Color(0xFF35312A),
    isDark: true,
  );

  // ── Nocturne ────────────────────────────────────────────────────────────
  // Deep indigo dark mode, lavender primary, teal secondary.

  static const AppColorPalette nocturneDark = AppColorPalette(
    background: Color(0xFF0B0C16),
    surface: Color(0xFF14151F),
    border: Color(0xFF2C2D38),
    surfaceVariant: Color(0xFF1C1E2D),
    ink: Color(0xFF05050D),
    onInk: Color(0xFFEDEEF5),
    onInkMuted: Color(0xFF7D7F8C),
    primary: Color(0xFFA0A6F3),
    primaryHighlight: Color(0xFFC2C8FF),
    primaryDark: Color(0xFF7377C6),
    secondary: Color(0xFF56B6BB),
    secondaryLight: Color(0xFF8DD2D6),
    attention: Color(0xFFE6857E),
    success: Color(0xFF62BB78),
    warning: Color(0xFFE29E47),
    danger: Color(0xFFE85854),
    textPrimary: Color(0xFFEDEEF5),
    textSecondary: Color(0xFFA2A4AE),
    textTertiary: Color(0xFF6F717D),
    overlayDark: Color(0xCC030309),
    shimmerBase: Color(0xFF1D1E29),
    shimmerHighlight: Color(0xFF31323D),
    isDark: true,
  );

  static const AppColorPalette nocturneLight = AppColorPalette(
    background: Color(0xFFF3F3FA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE1E1F0),
    surfaceVariant: Color(0xFFEAEAF6),
    ink: Color(0xFF0D0E1A),
    onInk: Color(0xFFF3F3FA),
    onInkMuted: Color(0xFFABADC2),
    primary: Color(0xFF5A5FC0), // darkened lavender
    primaryHighlight: Color(0xFF8286DE),
    primaryDark: Color(0xFF3E4291),
    secondary: Color(0xFF2A8A8F), // darkened teal
    secondaryLight: Color(0xFF56B6BB),
    attention: Color(0xFFC85850),
    success: Color(0xFF3F9A57),
    warning: Color(0xFFB97D2C),
    danger: Color(0xFFD03530),
    textPrimary: Color(0xFF14151F),
    textSecondary: Color(0xFF5C5E70),
    textTertiary: Color(0xFF8B8DA0),
    overlayDark: Color(0xCC030309),
    shimmerBase: Color(0xFFE7E7F2),
    shimmerHighlight: Color(0xFFF0F0F8),
    isDark: false,
  );

  // ── Trail Social ────────────────────────────────────────────────────────
  // Dark social-feed base, kudos-orange primary, blue secondary.

  static const AppColorPalette trailSocialDark = AppColorPalette(
    background: Color(0xFF101418),
    surface: Color(0xFF1C2024),
    border: Color(0xFF2F3338),
    surfaceVariant: Color(0xFF25292E),
    ink: Color(0xFF05080B),
    onInk: Color(0xFFF8F8F8),
    onInkMuted: Color(0xFF7C8186),
    primary: Color(0xFFF5642B),
    primaryHighlight: Color(0xFFFF9661),
    primaryDark: Color(0xFFBF4213),
    secondary: Color(0xFF53A3F2),
    secondaryLight: Color(0xFF8CC3FC),
    attention: Color(0xFFEB881F),
    success: Color(0xFF54B85B),
    warning: Color(0xFFE49E22),
    danger: Color(0xFFE64343),
    textPrimary: Color(0xFFF3F5F8),
    textSecondary: Color(0xFFA0A5AB),
    textTertiary: Color(0xFF6D7277),
    overlayDark: Color(0xCC030507),
    shimmerBase: Color(0xFF25292E),
    shimmerHighlight: Color(0xFF393E42),
    isDark: true,
  );

  static const AppColorPalette trailSocialLight = AppColorPalette(
    background: Color(0xFFF8F7F5),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E2DE),
    surfaceVariant: Color(0xFFEFECE8),
    ink: Color(0xFF0A0C0E),
    onInk: Color(0xFFF8F7F5),
    onInkMuted: Color(0xFFB0ADA8),
    primary: Color(0xFFC2451A), // darkened kudos orange
    primaryHighlight: Color(0xFFF5642B),
    primaryDark: Color(0xFF8F3110),
    secondary: Color(0xFF1F6FC4), // darkened blue
    secondaryLight: Color(0xFF53A3F2),
    attention: Color(0xFFB9660F),
    success: Color(0xFF2F8F37),
    warning: Color(0xFFB67A15),
    danger: Color(0xFFC22626),
    textPrimary: Color(0xFF14171A),
    textSecondary: Color(0xFF5E6367),
    textTertiary: Color(0xFF8D9195),
    overlayDark: Color(0xCC030507),
    shimmerBase: Color(0xFFEDEAE6),
    shimmerHighlight: Color(0xFFF5F3F0),
    isDark: false,
  );

  // ── Calming ─────────────────────────────────────────────────────────────
  // Warm cream light mode, sage primary, tan secondary.

  static const AppColorPalette calmingLight = AppColorPalette(
    background: Color(0xFFF8F5EF),
    surface: Color(0xFFFEFBF8),
    border: Color(0xFFE1DDD8),
    surfaceVariant: Color(0xFFEEEBE5),
    ink: Color(0xFF2B2823),
    onInk: Color(0xFFF8F5EF),
    onInkMuted: Color(0xFFB1ADA7),
    primary: Color(0xFF84A98B),
    primaryHighlight: Color(0xFFA8C7AD),
    primaryDark: Color(0xFF537D5C),
    secondary: Color(0xFFBD8D65),
    secondaryLight: Color(0xFFDBB597),
    attention: Color(0xFFB88255),
    success: Color(0xFF5D9669),
    warning: Color(0xFFCD995C),
    danger: Color(0xFFC34F4B),
    textPrimary: Color(0xFF2B2823),
    textSecondary: Color(0xFF66635D),
    textTertiary: Color(0xFF898680),
    overlayDark: Color(0xCC24211C),
    shimmerBase: Color(0xFFE7E4DF),
    shimmerHighlight: Color(0xFFF5F1EC),
    isDark: false,
  );

  static const AppColorPalette calmingDark = AppColorPalette(
    background: Color(0xFF17170F),
    surface: Color(0xFF211F16),
    border: Color(0xFF3A3826),
    surfaceVariant: Color(0xFF262418),
    ink: Color(0xFF0A0A07),
    onInk: Color(0xFFF8F5EF),
    onInkMuted: Color(0xFF706E60),
    primary: Color(0xFFA8C7AD), // was calmingLight.primaryHighlight
    primaryHighlight: Color(0xFFC7DECB),
    primaryDark: Color(0xFF84A98B), // was calmingLight.primary
    secondary: Color(0xFFDBB597), // was calmingLight.secondaryLight
    secondaryLight: Color(0xFFEAD0BC),
    attention: Color(0xFFD6A578),
    success: Color(0xFF7EBB8A),
    warning: Color(0xFFE0B784),
    danger: Color(0xFFDC7672),
    textPrimary: Color(0xFFF8F5EF),
    textSecondary: Color(0xFFB4B0A5),
    textTertiary: Color(0xFF837F72),
    overlayDark: Color(0xCC24211C),
    shimmerBase: Color(0xFF262418),
    shimmerHighlight: Color(0xFF3A3826),
    isDark: true,
  );

  // ── Retro ───────────────────────────────────────────────────────────────
  // The deck's old monochrome terminal: no chroma anywhere, severity encoded
  // in value rather than hue (see the design note on `retroLight` — it
  // applies identically, mirrored, to `retroDark`). The dark companion
  // inverts which end is "ink": on paper, the boldest mark is black-on-white;
  // on the terminal-dark companion, it's white-on-black, so `ink`/`onInk`
  // swap roles rather than just darkening in place.

  static const AppColorPalette retroLight = AppColorPalette(
    background: Color(0xFFFAFAF7),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFF0A0A0A), // the hard rule, not a hairline tint
    surfaceVariant: Color(0xFFEAEAE5),
    ink: Color(0xFF0A0A0A),
    onInk: Color(0xFFFAFAF7),
    onInkMuted: Color(0xFF9A9A93),
    primary: Color(0xFF0A0A0A), // the accent is ink; there is no accent hue
    primaryHighlight: Color(0xFF3D3D39),
    primaryDark: Color(0xFF000000),
    secondary: Color(0xFF4A4A45),
    secondaryLight: Color(0xFF7C7C75),
    attention: Color(0xFF1F1F1C),
    success: Color(0xFF5C5C56), // recedes
    warning: Color(0xFF333330),
    danger: Color(0xFF0A0A0A), // loudest mark on paper
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF56564F),
    textTertiary: Color(0xFF86867E),
    overlayDark: Color(0xCC0A0A0A),
    shimmerBase: Color(0xFFE6E6E1),
    shimmerHighlight: Color(0xFFF5F5F1),
    isDark: false,
  );

  static const AppColorPalette retroDark = AppColorPalette(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF121212),
    border: Color(0xFFFAFAF7), // the hard rule, inverted: matches `ink` exactly
    surfaceVariant: Color(0xFF1C1C1A),
    ink: Color(0xFFFAFAF7), // boldest fill is white-on-black here
    onInk: Color(0xFF0A0A0A),
    onInkMuted: Color(0xFF6B6B66),
    primary: Color(0xFFFAFAF7), // the accent is onInk; still no accent hue
    primaryHighlight: Color(0xFFC6C6C0),
    primaryDark: Color(0xFFFFFFFF),
    secondary: Color(0xFFB5B5AE),
    secondaryLight: Color(0xFFD8D8D2),
    attention: Color(0xFFE0E0DA),
    success: Color(0xFF8A8A83), // recedes toward the background
    warning: Color(0xFFC2C2BB),
    danger: Color(0xFFFAFAF7), // loudest mark on black
    textPrimary: Color(0xFFFAFAF7),
    textSecondary: Color(0xFFA8A8A1),
    textTertiary: Color(0xFF6E6E68),
    overlayDark: Color(0xCC0A0A0A),
    shimmerBase: Color(0xFF1C1C1A),
    shimmerHighlight: Color(0xFF2A2A26),
    isDark: true,
  );

  // ── Analyst Blue ────────────────────────────────────────────────────────
  // Navy monitoring console, cyan telemetry primary, coral secondary.

  static const AppColorPalette analystBlueDark = AppColorPalette(
    background: Color(0xFF0B1C2C),
    surface: Color(0xFF172534),
    border: Color(0xFF2F3C4A),
    surfaceVariant: Color(0xFF222F3C),
    ink: Color(0xFF050C13),
    onInk: Color(0xFFFCFCFC),
    onInkMuted: Color(0xFF738292),
    primary: Color(0xFF25C0E6),
    primaryHighlight: Color(0xFF7DDDFB),
    primaryDark: Color(0xFF008FBA),
    secondary: Color(0xFFF3906D),
    secondaryLight: Color(0xFFFEB391),
    attention: Color(0xFFF3906D),
    success: Color(0xFF5DC879),
    warning: Color(0xFFEBA941),
    danger: Color(0xFFF14D4C),
    textPrimary: Color(0xFFF3F5F8),
    textSecondary: Color(0xFF9BA6B1),
    textTertiary: Color(0xFF69737D),
    overlayDark: Color(0xCC020A15),
    shimmerBase: Color(0xFF222F3C),
    shimmerHighlight: Color(0xFF364452),
    isDark: true,
  );

  static const AppColorPalette analystBlueLight = AppColorPalette(
    background: Color(0xFFF2F7FA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFDCE6EC),
    surfaceVariant: Color(0xFFE8F0F5),
    ink: Color(0xFF061019),
    onInk: Color(0xFFF2F7FA),
    onInkMuted: Color(0xFFA3B0BB),
    primary: Color(0xFF0A7F9E), // darkened console cyan
    primaryHighlight: Color(0xFF25C0E6),
    primaryDark: Color(0xFF075A70),
    secondary: Color(0xFFC15A38), // darkened coral
    secondaryLight: Color(0xFFF3906D),
    attention: Color(0xFFC15A38),
    success: Color(0xFF2E9A4C),
    warning: Color(0xFFB87F1F),
    danger: Color(0xFFCC2A29),
    textPrimary: Color(0xFF0C1620),
    textSecondary: Color(0xFF5A6A77),
    textTertiary: Color(0xFF8A97A2),
    overlayDark: Color(0xCC020A15),
    shimmerBase: Color(0xFFE4EDF2),
    shimmerHighlight: Color(0xFFEFF5F8),
    isDark: false,
  );

  /// Exhaustive by design — a nested `switch` with no `default`, so adding a
  /// member to [AppColorMode] or to [Brightness] without a palette is a
  /// compile error rather than a mode that silently renders as Carbon Mono.
  static AppColorPalette forMode(AppColorMode mode, Brightness brightness) =>
      switch ((mode, brightness)) {
        (AppColorMode.carbonMono, Brightness.dark) => carbonMonoDark,
        (AppColorMode.carbonMono, Brightness.light) => carbonMonoLight,
        (AppColorMode.editorial, Brightness.dark) => editorialDark,
        (AppColorMode.editorial, Brightness.light) => editorialLight,
        (AppColorMode.nocturne, Brightness.dark) => nocturneDark,
        (AppColorMode.nocturne, Brightness.light) => nocturneLight,
        (AppColorMode.trailSocial, Brightness.dark) => trailSocialDark,
        (AppColorMode.trailSocial, Brightness.light) => trailSocialLight,
        (AppColorMode.calming, Brightness.dark) => calmingDark,
        (AppColorMode.calming, Brightness.light) => calmingLight,
        (AppColorMode.retro, Brightness.dark) => retroDark,
        (AppColorMode.retro, Brightness.light) => retroLight,
        (AppColorMode.analystBlue, Brightness.dark) => analystBlueDark,
        (AppColorMode.analystBlue, Brightness.light) => analystBlueLight,
      };
}
