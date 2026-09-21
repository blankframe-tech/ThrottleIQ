import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_shape_profile.dart';
import 'app_theme_style.dart';
import 'app_typography.dart';
import 'theme_style_provider.dart';

class AppTheme {
  AppTheme._();

  /// Builds the [ThemeData] for the given [AppAppearance]. Resolves the
  /// matching [AppColorPalette] and [AppShapeProfile] and registers both as
  /// [ThemeData.extensions], which is how every widget reads them
  /// (`context.palette` / `context.shape`, see `app_theme_context.dart`).
  /// Display/heading type uses IBM Plex Mono; body uses IBM Plex Sans.
  ///
  /// Shape is per-appearance, not shared: Curvy gets rounded corners and
  /// roomier controls, Boxy keeps the sharp instrument-panel edges — see
  /// [AppShapeProfile.forVibe]. Nothing about the layout hierarchy changes
  /// with the appearance, only how the same widgets are drawn.
  ///
  /// Retro remains the one color mode that is more than shape and color: it
  /// drops body type to monospace regardless of which shape/brightness it's
  /// paired with, and its mustard accent always takes dark ink text rather
  /// than the white/surface foreground every other mode's primary button
  /// gets — matching the "Retro (Rawblock)" deck direction, where the accent
  /// fill is light enough that white text would fail contrast. See
  /// [AppColorPalette.retroLight]/[AppColorPalette.retroDark].
  /// Text/icon color drawn on a filled `primary` button for [palette].
  /// Pulled out of [build] so the WCAG contrast test can check every
  /// palette against exactly what the button renders.
  static Color primaryButtonForeground(AppColorPalette palette,
          {required bool isRetro}) =>
      isRetro
          ? const Color(0xFF1A1A1A)
          : (palette.isDark ? palette.surface : Colors.white);

  static ThemeData build(AppAppearance appearance) {
    final isDark = appearance.brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    final isRetro = appearance.colorMode == AppColorMode.retro;
    final palette =
        AppColorPalette.forMode(appearance.colorMode, appearance.brightness);
    final shape = AppShapeProfile.forVibe(appearance.shapeVibe);

    // Body in IBM Plex Sans — or IBM Plex Mono end-to-end on Retro, where a
    // proportional body face would break the illusion the rest of the
    // direction is building.
    final bodyText = isRetro
        ? GoogleFonts.ibmPlexMonoTextTheme(base.textTheme)
        : GoogleFonts.ibmPlexSansTextTheme(base.textTheme);
    final textTheme = bodyText
        .copyWith(
          displayLarge: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.displayLarge,
              fontWeight: FontWeight.w700,
              letterSpacing: -1),
          displayMedium: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.displayMedium,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          displaySmall: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.displaySmall, fontWeight: FontWeight.w700),
          headlineLarge: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.headlineLarge,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineMedium: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.headlineMedium, fontWeight: FontWeight.w700),
          headlineSmall: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.headlineSmall, fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.ibmPlexMono(
              textStyle: bodyText.titleLarge, fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
          // Bengali fallback for every named style in the theme — see
          // AppTypography.bengaliFallback and pubspec.yaml. This is what
          // covers plain `Text(...)` widgets that take their style from
          // `Theme.of(context).textTheme` rather than calling GoogleFonts
          // directly; the handful of standalone TextStyles below (app bar
          // title, button labels, snackbar) need their own since they never
          // go through this TextTheme.
          fontFamilyFallback: AppTypography.bengaliFallback,
        );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[palette, shape],
      scaffoldBackgroundColor: palette.background,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: palette.primary,
              onPrimary: palette.surface,
              secondary: palette.secondary,
              onSecondary: Colors.white,
              surface: palette.surface,
              onSurface: palette.textPrimary,
              error: palette.danger,
              onError: Colors.white,
              outline: palette.border,
            )
          : ColorScheme.light(
              primary: palette.primary,
              onPrimary: Colors.white,
              secondary: palette.secondary,
              onSecondary: Colors.white,
              surface: palette.surface,
              onSurface: palette.textPrimary,
              error: palette.danger,
              onError: Colors.white,
              outline: palette.border,
            ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.ibmPlexMono(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ).copyWith(fontFamilyFallback: AppTypography.bengaliFallback),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shape.radiusXl),
          side: BorderSide(color: palette.border, width: shape.outlineWidth),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: EdgeInsets.symmetric(
            horizontal: shape.fieldPaddingH,
            vertical: shape.fieldPaddingV),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.radiusMd),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.radiusMd),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.radiusMd),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.radiusMd),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.radiusMd),
          borderSide: BorderSide(color: palette.danger, width: 2),
        ),
        hintStyle: TextStyle(color: palette.textTertiary),
        labelStyle: TextStyle(color: palette.textSecondary),
      ),
      // Primary action = accent pop (lime on Carbon Mono, blue on Editorial,
      // and whatever the selected skin's `primary` is).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          // Retro's mustard accent is a mid-light fill in both brightnesses,
          // so it always takes dark ink text rather than flipping with
          // brightness the way every other mode's white/surface text does.
          foregroundColor: primaryButtonForeground(palette, isRetro: isRetro),
          elevation: 0,
          minimumSize: Size.fromHeight(shape.controlHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shape.radiusMd),
          ),
          textStyle: GoogleFonts.ibmPlexMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ).copyWith(fontFamilyFallback: AppTypography.bengaliFallback),
        ),
      ),
      // Secondary action = neutral outline.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: Size.fromHeight(shape.controlHeight),
          side: BorderSide(
              color: palette.textPrimary,
              width: shape.emphasisOutlineWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shape.radiusMd),
          ),
          textStyle: GoogleFonts.ibmPlexMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ).copyWith(fontFamilyFallback: AppTypography.bengaliFallback),
        ),
      ),
      // Links = accent pop.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // Ink snackbar for contrast against either palette.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: GoogleFonts.ibmPlexSans(color: palette.onInk)
            .copyWith(fontFamilyFallback: AppTypography.bengaliFallback),
        actionTextColor: palette.primaryHighlight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shape.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
