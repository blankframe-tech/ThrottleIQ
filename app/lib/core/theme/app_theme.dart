import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_theme_style.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  /// Builds the [ThemeData] for the given [AppThemeStyle]. Reads current
  /// values off [AppColors] and [AppDimensions], both of which must already
  /// have had the matching [AppColorPalette] and [AppShapeProfile] applied
  /// (see `theme_style_provider.dart`). Display/heading type uses IBM Plex
  /// Mono; body uses IBM Plex Sans.
  ///
  /// Shape is per-skin, not shared: some directions get rounded corners and
  /// roomier controls, others keep the sharp instrument-panel edges — see
  /// [AppShapeProfile.forStyle]. Nothing about the layout hierarchy changes
  /// with the skin, only how the same widgets are drawn.
  ///
  /// Retro remains the one skin that is more than shape and color. On top of
  /// [AppShapeProfile.terminal]'s square corners and doubled rules it also
  /// drops body type to monospace, which is the only style branch left in this
  /// method. See [AppColorPalette.retro].
  static ThemeData build(AppThemeStyle style) {
    final isDark = AppColorPalette.forStyle(style).isDark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    final isTerminal = style == AppThemeStyle.retro;

    // Body in IBM Plex Sans — or IBM Plex Mono end-to-end on the terminal
    // skin, where a proportional body face would break the illusion the
    // rest of the direction is building.
    final bodyText = isTerminal
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
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
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
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.surface,
              secondary: AppColors.secondary,
              onSecondary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
              error: AppColors.danger,
              onError: Colors.white,
              outline: AppColors.border,
            )
          : ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.secondary,
              onSecondary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
              error: AppColors.danger,
              onError: Colors.white,
              outline: AppColors.border,
            ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.ibmPlexMono(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ).copyWith(fontFamilyFallback: AppTypography.bengaliFallback),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: BorderSide(color: AppColors.border, width: AppDimensions.outlineWidth),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppDimensions.fieldPaddingH,
            vertical: AppDimensions.fieldPaddingV),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle: TextStyle(color: AppColors.textTertiary),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),
      // Primary action = accent pop (lime on Carbon Mono, blue on Editorial,
      // and whatever the selected skin's `primary` is).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: isDark ? AppColors.surface : Colors.white,
          elevation: 0,
          minimumSize: Size.fromHeight(AppDimensions.controlHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
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
          foregroundColor: AppColors.textPrimary,
          minimumSize: Size.fromHeight(AppDimensions.controlHeight),
          side: BorderSide(
              color: AppColors.textPrimary,
              width: AppDimensions.emphasisOutlineWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
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
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // Ink snackbar for contrast against either palette.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.ibmPlexSans(color: AppColors.onInk)
            .copyWith(fontFamilyFallback: AppTypography.bengaliFallback),
        actionTextColor: AppColors.primaryHighlight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
