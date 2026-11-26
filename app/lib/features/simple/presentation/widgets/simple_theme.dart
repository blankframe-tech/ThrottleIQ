import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/theme/app_typography.dart';

/// Simple mode's look over the app theme: sans type only (no mono), the
/// accent fill kept for the one main action, neutral outlined buttons, 52dp
/// controls and one corner radius. Every Simple screen wraps itself in this;
/// sheets opened from a Simple screen inherit it.
class SimpleTheme extends StatelessWidget {
  const SimpleTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final p = context.palette;
    final t = base.textTheme;
    // Only weights bundled in assets/google_fonts/: Space Grotesk 500-700
    // for headings, numbers and buttons; body styles keep IBM Plex Sans 400.
    TextStyle g(TextStyle? s, FontWeight w) =>
        GoogleFonts.spaceGrotesk(textStyle: s, fontWeight: w, letterSpacing: 0)
            .copyWith(fontFamilyFallback: AppTypography.bengaliFallback);
    final button = g(t.labelLarge, FontWeight.w600).copyWith(fontSize: 15);
    const size = Size(64, 52);
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.shape.radiusLg));

    return Theme(
      data: base.copyWith(
        textTheme: t.copyWith(
          displayLarge: g(t.displayLarge, FontWeight.w700),
          displayMedium: g(t.displayMedium, FontWeight.w700),
          displaySmall: g(t.displaySmall, FontWeight.w700),
          headlineLarge: g(t.headlineLarge, FontWeight.w700),
          headlineMedium: g(t.headlineMedium, FontWeight.w700),
          headlineSmall: g(t.headlineSmall, FontWeight.w700),
          titleLarge: g(t.titleLarge, FontWeight.w700),
          titleMedium: g(t.titleMedium, FontWeight.w600),
          titleSmall: g(t.titleSmall, FontWeight.w600),
          labelLarge: button,
          labelMedium: g(t.labelMedium, FontWeight.w500),
          labelSmall: g(t.labelSmall, FontWeight.w500),
        ),
        appBarTheme: base.appBarTheme.copyWith(
            titleTextStyle:
                g(base.appBarTheme.titleTextStyle, FontWeight.w700)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: size, shape: shape, textStyle: button),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: button,
            foregroundColor: p.textPrimary,
            side: BorderSide(color: p.textTertiary.withValues(alpha: 0.5)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: shape,
            textStyle: button,
            foregroundColor: p.primary,
          ),
        ),
        expansionTileTheme: const ExpansionTileThemeData(
            shape: Border(), collapsedShape: Border()),
      ),
      child: child,
    );
  }
}
