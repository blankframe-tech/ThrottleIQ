import 'package:flutter/material.dart';
import '../theme/app_theme_style.dart';

/// Runtime-swappable color tokens for ThrottleIQ.
///
/// Backed by an [AppColorPalette] (Carbon Mono, Boxy, Dark by default) that
/// [apply] swaps out when the user changes their appearance preference
/// (color mode and/or brightness) in Settings — see
/// `theme_style_provider.dart`.
///
/// Field names are kept stable so the ~565 references across the app pick up
/// whichever palette is current without call-site churn. Because these are
/// now getters rather than `static const` fields, any `const` expression
/// that embedded one of them (e.g. `const TextStyle(color: AppColors.x)`)
/// must drop the `const` keyword.
class AppColors {
  AppColors._();

  static AppColorPalette _current = AppColorPalette.carbonMonoDark;

  static void apply(AppColorPalette palette) {
    _current = palette;
  }

  // Base
  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get border => _current.border;
  static Color get surfaceVariant => _current.surfaceVariant;

  // Ink — solid panels (hero, headers, icon tiles)
  static Color get ink => _current.ink;
  static Color get onInk => _current.onInk;
  static Color get onInkMuted => _current.onInkMuted;

  // Primary — the main accent "pop" (badges, scores, chart lines, CTAs)
  static Color get primary => _current.primary;
  static Color get primaryHighlight => _current.primaryHighlight;
  static Color get primaryDark => _current.primaryDark;

  // Secondary / attention
  static Color get secondary => _current.secondary;
  static Color get secondaryLight => _current.secondaryLight;
  static Color get attention => _current.attention;

  // Status
  static Color get success => _current.success;
  static Color get warning => _current.warning;
  static Color get danger => _current.danger;

  // Text
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textTertiary => _current.textTertiary;

  // Overlays / shimmer
  static Color get overlayDark => _current.overlayDark;
  static Color get shimmerBase => _current.shimmerBase;
  static Color get shimmerHighlight => _current.shimmerHighlight;
}
