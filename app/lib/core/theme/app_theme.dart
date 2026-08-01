import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_theme_style.dart';

class AppTheme {
  AppTheme._();

  /// Builds the [ThemeData] for the given [AppThemeStyle]. Reads current
  /// values off [AppColors], which must already have had the matching
  /// [AppColorPalette] applied (see `theme_style_provider.dart`) — shape and
  /// typography are shared by both styles; only the color palette and base
  /// brightness differ. Display/heading type uses IBM Plex Mono; body uses
  /// IBM Plex Sans.
  static ThemeData build(AppThemeStyle style) {
    final isDark = style == AppThemeStyle.carbonMono;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    // Body in IBM Plex Sans, display/headings/titles in IBM Plex Mono.
    final bodyText = GoogleFonts.ibmPlexSansTextTheme(base.textTheme);
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
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

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
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      // Primary action = accent pop (lime on Carbon Mono, blue on Editorial).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: isDark ? AppColors.surface : Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: GoogleFonts.ibmPlexMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      // Secondary action = neutral outline.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: GoogleFonts.ibmPlexMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
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
        contentTextStyle: GoogleFonts.ibmPlexSans(color: AppColors.onInk),
        actionTextColor: AppColors.primaryHighlight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
