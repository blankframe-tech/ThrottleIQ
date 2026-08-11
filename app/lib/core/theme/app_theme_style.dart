import 'package:flutter/material.dart';

/// The selectable design languages ("skins"). All of them share the same
/// shape system and IBM Plex typography — only the color palette (and, via
/// [AppColorPalette.isDark], the base brightness and app logo) differ.
///
/// The first two are the app's original pair. The rest are the seven style
/// directions from `ThrottleIQ Style Directions`, translated from the
/// mockups' oklch values into the same 22-token contract every screen already
/// reads through [AppColors].
///
/// Enum member names are the persisted values (see `theme_style_provider.dart`)
/// — renaming one silently resets riders who had it selected.
enum AppThemeStyle {
  carbonMono,
  editorial,
  nocturne,
  trailSocial,
  calming,
  positiveVibes,
  retro,
  analystBlue,
  genesis,
}

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

  /// Whether this palette sits on a dark base. Drives the Material
  /// `ThemeData` brightness, the `ColorScheme` variant and the status-bar
  /// icon color in `app_theme.dart`, and which app mark `AppLogo` shows —
  /// all of which used to be inferred from `style == carbonMono`, which
  /// stopped being a usable proxy the moment there was more than one dark
  /// skin.
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
    isDark: true,
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
    isDark: false,
  );

  // ── Style directions ───────────────────────────────────────────────────
  //
  // The seven skins below come from the `ThrottleIQ Style Directions` deck.
  // The mockups specify colors in oklch; these are the sRGB conversions.
  // Where a direction's three screens didn't name a token the app needs
  // (most of them have no distinct `secondary`, and none define shimmer or
  // status colors), the value is derived in the same oklch space — same
  // lightness family, a hue that stays inside the direction's story — so a
  // skin never falls back to another skin's accent.

  /// "Nocturne" — deep indigo dark mode, soft lavender glow accent.
  static const AppColorPalette nocturne = AppColorPalette(
    background: Color(0xFF0B0C16),
    surface: Color(0xFF14151F),
    border: Color(0xFF2C2D38),
    surfaceVariant: Color(0xFF1C1E2D),
    ink: Color(0xFF05050D),
    onInk: Color(0xFFEDEEF5),
    onInkMuted: Color(0xFF7D7F8C),
    primary: Color(0xFFA0A6F3), // lavender glow
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

  /// "Trail Social" — dark social-feed base, punchy orange accent.
  static const AppColorPalette trailSocial = AppColorPalette(
    background: Color(0xFF101418),
    surface: Color(0xFF1C2024),
    border: Color(0xFF2F3338),
    surfaceVariant: Color(0xFF25292E),
    ink: Color(0xFF05080B),
    onInk: Color(0xFFF8F8F8),
    onInkMuted: Color(0xFF7C8186),
    primary: Color(0xFFF5642B), // kudos orange
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

  /// "Calming" — warm cream light mode, soft sage accent.
  static const AppColorPalette calming = AppColorPalette(
    background: Color(0xFFF8F5EF),
    surface: Color(0xFFFEFBF8),
    border: Color(0xFFE1DDD8),
    surfaceVariant: Color(0xFFEEEBE5),
    ink: Color(0xFF2B2823),
    onInk: Color(0xFFF8F5EF),
    onInkMuted: Color(0xFFB1ADA7),
    primary: Color(0xFF84A98B), // sage
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

  /// "Positive Vibes" — bright white-and-green, health-app energy.
  static const AppColorPalette positiveVibes = AppColorPalette(
    background: Color(0xFFFAFAF8),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE1E6E0),
    surfaceVariant: Color(0xFFE4F4E1),
    ink: Color(0xFF1A3520),
    onInk: Color(0xFFFBFCF9),
    onInkMuted: Color(0xFFAFBBB1),
    primary: Color(0xFF54BF5C), // verdant green
    primaryHighlight: Color(0xFF8CDA8F),
    primaryDark: Color(0xFF278733),
    secondary: Color(0xFF00B9C3),
    secondaryLight: Color(0xFF6BD8DE),
    attention: Color(0xFFDCA331),
    success: Color(0xFF3BA946),
    warning: Color(0xFFDCA331),
    danger: Color(0xFFDB4241),
    textPrimary: Color(0xFF1A3520),
    textSecondary: Color(0xFF5C675D),
    textTertiary: Color(0xFF879389),
    overlayDark: Color(0xCC17261A),
    shimmerBase: Color(0xFFE8EDE7),
    shimmerHighlight: Color(0xFFF2F7F0),
    isDark: false,
  );

  /// "Retro" — the deck's blocky Rawblock geometry (thick hard rules, hard
  /// offset shadows, no rounded corners) rendered as an old monochrome
  /// terminal: black ink on paper white, and **no chroma anywhere**.
  ///
  /// Two things make this palette unlike every other one here.
  ///
  /// `border` is full-strength ink rather than a hairline tint. On the other
  /// skins the border is a whisper between two surfaces; here the heavy black
  /// rule *is* the design, and softening it would just produce a bland light
  /// theme.
  ///
  /// The status colors are a grey ramp, not hues. A strictly black-and-white
  /// skin has no red to spend on danger, so severity is encoded in *value*
  /// instead: danger is pure ink (the loudest mark available on paper),
  /// warning a dark grey, success a mid grey that recedes. This is a real
  /// trade — two states that differ only in weight are harder to tell apart
  /// at a glance than red-vs-green — and it is the deliberate cost of the
  /// direction. Every status in the app pairs its color with an icon or a
  /// word, so nothing here is conveyed by color alone.
  ///
  /// [AppTheme.build] gives this skin monospace body type and square corners
  /// to finish the terminal read; it's the only palette that changes shape
  /// and typography, not just color.
  static const AppColorPalette retro = AppColorPalette(
    background: Color(0xFFFAFAF7), // paper
    surface: Color(0xFFFFFFFF),
    border: Color(0xFF0A0A0A), // the hard rule — see above
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

  /// "Analyst Blue" — navy monitoring console, cyan telemetry accent.
  static const AppColorPalette analystBlue = AppColorPalette(
    background: Color(0xFF0B1C2C),
    surface: Color(0xFF172534),
    border: Color(0xFF2F3C4A),
    surfaceVariant: Color(0xFF222F3C),
    ink: Color(0xFF050C13),
    onInk: Color(0xFFFCFCFC),
    onInkMuted: Color(0xFF738292),
    primary: Color(0xFF25C0E6), // console cyan
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

  /// "Genesis" — premium near-black, gold primary with a violet secondary.
  static const AppColorPalette genesis = AppColorPalette(
    background: Color(0xFF080811),
    surface: Color(0xFF14121E),
    border: Color(0xFF313142),
    surfaceVariant: Color(0xFF1D1E29),
    ink: Color(0xFF030307),
    onInk: Color(0xFFEDEEF5),
    onInkMuted: Color(0xFF838592),
    primary: Color(0xFFEAB532), // gold
    primaryHighlight: Color(0xFFF6D480),
    primaryDark: Color(0xFFB68611),
    secondary: Color(0xFF9260DA), // violet
    secondaryLight: Color(0xFFB48DF4),
    attention: Color(0xFFF68F5F),
    success: Color(0xFF65C67D),
    warning: Color(0xFFEAB532),
    danger: Color(0xFFED5350),
    textPrimary: Color(0xFFF0F1F9),
    textSecondary: Color(0xFFACADB8),
    textTertiary: Color(0xFF787986),
    overlayDark: Color(0xCC010104),
    shimmerBase: Color(0xFF1D1E29),
    shimmerHighlight: Color(0xFF31323D),
    isDark: true,
  );

  /// Exhaustive by design — a `switch` with no `default`, so adding a member
  /// to [AppThemeStyle] without a palette is a compile error rather than a
  /// skin that silently renders as Carbon Mono.
  static AppColorPalette forStyle(AppThemeStyle style) => switch (style) {
        AppThemeStyle.carbonMono => carbonMono,
        AppThemeStyle.editorial => editorial,
        AppThemeStyle.nocturne => nocturne,
        AppThemeStyle.trailSocial => trailSocial,
        AppThemeStyle.calming => calming,
        AppThemeStyle.positiveVibes => positiveVibes,
        AppThemeStyle.retro => retro,
        AppThemeStyle.analystBlue => analystBlue,
        AppThemeStyle.genesis => genesis,
      };
}
