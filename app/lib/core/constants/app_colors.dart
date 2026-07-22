import 'package:flutter/material.dart';

/// ThrottleIQ "Editorial BW" palette.
///
/// A light, warm, print-editorial base (cream paper + near-black ink + warm
/// gray hairlines) with a deliberately restrained accent system:
///   - ORANGE is the attention / action color (primary buttons, focus, active)
///   - BLUE is a minimal secondary accent (links, subtle highlights)
/// Semantic greens/ambers/reds are used only for status.
///
/// Field names are kept stable so the ~450 references across the app pick up
/// the editorial values without churn.
class AppColors {
  AppColors._();

  // Base — warm editorial paper
  static const Color background = Color(0xFFF4F1EC); // cream paper
  static const Color surface = Color(0xFFFAF9F6); // card / raised paper
  static const Color border = Color(0xFFE8E5DF); // warm hairline
  static const Color surfaceVariant = Color(0xFFF0EEE9); // subtle fill

  // Primary (Orange) — attention / action
  static const Color primary = Color(0xFFF2703C);
  static const Color primaryHighlight = Color(0xFFF58C5F);
  static const Color primaryDark = Color(0xFFD8551F);

  // Secondary (Blue) — minimal accent
  static const Color secondary = Color(0xFF3B6CF6);
  static const Color secondaryLight = Color(0xFF6B90F8);

  // Status
  static const Color success = Color(0xFF1AA568);
  static const Color warning = Color(0xFFE8A13B);
  static const Color danger = Color(0xFFE5484D);

  // Text — ink on paper
  static const Color textPrimary = Color(0xFF141414); // ink
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9A9A9A);

  // Overlays / shimmer
  static const Color overlayDark = Color(0xCC141414); // ink scrim
  static const Color shimmerBase = Color(0xFFE8E5DF);
  static const Color shimmerHighlight = Color(0xFFF0EEE9);
}
