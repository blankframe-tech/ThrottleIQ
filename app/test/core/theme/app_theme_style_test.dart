import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:throttleiq/core/constants/app_dimensions.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/app_typography.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';

/// The two-theme catalogue's invariants: one light palette, one dark one,
/// one shape profile, all registered on the theme `AppTheme.build` returns.
void main() {
  // AppTheme.build reaches google_fonts, which loads the asset manifest
  // through ServicesBinding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ...and, left to itself, then tries to *download* the font, because the
  // app ships no font assets and resolves IBM Plex at runtime. Under
  // flutter_test that download can never succeed (the binding installs an
  // HttpClient that fails every request), and google_fonts reports the
  // failure on a future nobody awaits — so it surfaced as "this test failed
  // after it had already completed" against whichever test was unlucky.
  //
  // Turning runtime fetching off makes the failure deterministic (a throw
  // about the missing asset rather than a network error) and [themeFor]
  // below contains it. These tests are about colors and shapes, not glyphs;
  // the fallback face they end up with is irrelevant to every assertion here.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// [AppTheme.build] with google_fonts' unloadable-font complaint swallowed.
  ThemeData themeFor(AppAppearance appearance) {
    late ThemeData theme;
    runZonedGuarded(
      () => theme = AppTheme.build(appearance),
      (error, stack) {
        // Anything that isn't the known font-asset gripe is a real failure
        // and must not be silently eaten.
        if (!error.toString().contains('google_fonts') &&
            !error
                .toString()
                .contains('was not found in the application assets')) {
          throw error;
        }
      },
    );
    return theme;
  }

  group('AppColorPalette', () {
    test('forBrightness picks Calming for light and Carbon Mono for dark', () {
      expect(AppColorPalette.forBrightness(Brightness.light),
          same(AppColorPalette.calmingLight));
      expect(AppColorPalette.forBrightness(Brightness.dark),
          same(AppColorPalette.carbonMonoDark));
    });

    test('isDark agrees with the brightness and the background luminance', () {
      // isDark drives ThemeData.brightness, the ColorScheme variant, the
      // status-bar icon color and which app mark is shown. A palette that
      // lies about it renders black system icons on a black bar.
      for (final brightness in Brightness.values) {
        final p = AppColorPalette.forBrightness(brightness);
        expect(p.isDark, brightness == Brightness.dark, reason: '$brightness');
        expect(p.isDark, p.background.computeLuminance() < 0.5,
            reason: '$brightness');
      }
    });

    test('text and accents stay readable against their own background', () {
      for (final brightness in Brightness.values) {
        final p = AppColorPalette.forBrightness(brightness);
        expect(_contrast(p.textPrimary, p.background), greaterThan(7.0),
            reason: '$brightness textPrimary');
        expect(_contrast(p.primary, p.background), greaterThanOrEqualTo(3.0),
            reason: '$brightness primary (AA for UI components)');
        expect(p.secondary, isNot(p.primary), reason: '$brightness');
      }
    });

    test('the two themes keep their identities', () {
      expect(AppColorPalette.calmingLight.background, const Color(0xFFF8F5EF));
      expect(AppColorPalette.calmingLight.primary, const Color(0xFF517959));
      expect(
          AppColorPalette.carbonMonoDark.background, const Color(0xFF0D0D0D));
      expect(AppColorPalette.carbonMonoDark.primary, const Color(0xFFC8FF3D));
    });

    test('the palette cross-fades colors and flips isDark at the halfway point',
        () {
      const a = AppColorPalette.carbonMonoDark;
      const b = AppColorPalette.calmingLight;
      expect(a.lerp(b, 0).primary, a.primary);
      expect(a.lerp(b, 1).primary, b.primary);
      expect(a.lerp(b, 0.5).primary, Color.lerp(a.primary, b.primary, 0.5));
      expect(a.lerp(b, 0.49).isDark, isTrue);
      expect(a.lerp(b, 0.5).isDark, isFalse);
    });

    test('copyWith overrides only what it is given', () {
      final p = AppColorPalette.calmingLight
          .copyWith(primary: const Color(0xFF123456));
      expect(p.primary, const Color(0xFF123456));
      expect(p.background, AppColorPalette.calmingLight.background);
    });
  });

  group('AppShapeProfile', () {
    test('radii are ordered sm ≤ md ≤ lg ≤ xl, with a true pill', () {
      const s = AppShapeProfile.curvy;
      expect(s.radiusSm, lessThanOrEqualTo(s.radiusMd));
      expect(s.radiusMd, lessThanOrEqualTo(s.radiusLg));
      expect(s.radiusLg, lessThanOrEqualTo(s.radiusXl));
      expect(s.radiusFull, greaterThanOrEqualTo(100));
    });

    test('spacing and chrome heights are not part of an appearance', () {
      expect(AppDimensions.paddingSm, 8);
      expect(AppDimensions.paddingMd, 16);
      expect(AppDimensions.paddingLg, 24);
      expect(AppDimensions.paddingXl, 32);
      expect(AppDimensions.bottomNavHeight, 72);
      expect(AppDimensions.appBarHeight, 64);
    });
  });

  group('AppTheme.build', () {
    test('registers the palette and shape for the brightness', () {
      // What `context.palette` / `context.shape` resolve through.
      for (final brightness in Brightness.values) {
        final theme = themeFor(AppAppearance(brightness: brightness));
        expect(theme.brightness, brightness);
        expect(theme.extension<AppColorPalette>(),
            same(AppColorPalette.forBrightness(brightness)));
        expect(theme.extension<AppShapeProfile>(), same(AppShapeProfile.curvy));
        final card = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect((card.borderRadius as BorderRadius).topLeft.x,
            AppShapeProfile.curvy.radiusXl);
      }
    });

    test('every named text style carries the Bengali fallback', () {
      // None of IBM Plex Mono, IBM Plex Sans, or Space Grotesk ship Bengali
      // glyphs (see AppTypography.bengaliFallback), so every style in the
      // theme needs the bundled fallback appended or Bangla text silently
      // drops to whatever face the platform substitutes.
      for (final brightness in Brightness.values) {
        final appearance = AppAppearance(brightness: brightness);
        final textTheme = themeFor(appearance).textTheme;
        for (final textStyle in [
          textTheme.displayLarge,
          textTheme.displayMedium,
          textTheme.displaySmall,
          textTheme.headlineLarge,
          textTheme.headlineMedium,
          textTheme.headlineSmall,
          textTheme.titleLarge,
          textTheme.bodyLarge,
          textTheme.bodyMedium,
          textTheme.bodySmall,
        ]) {
          expect(textStyle?.fontFamilyFallback,
              contains(AppTypography.bengaliFallback.single),
              reason: '$brightness');
        }
      }
    });

    test('the standalone text styles outside textTheme carry it too', () {
      // App bar title, button labels and the snackbar build their TextStyle
      // directly from GoogleFonts rather than through textTheme, so
      // textTheme's blanket .apply() never reaches them — each needs its own
      // fontFamilyFallback, verified here so a future edit that adds another
      // standalone GoogleFonts.xxx() call without it fails loudly.
      final theme = themeFor(AppAppearance.defaultAppearance);
      expect(theme.appBarTheme.titleTextStyle?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
      expect(
          theme.elevatedButtonTheme.style?.textStyle
              ?.resolve(const {})?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
      expect(
          theme.outlinedButtonTheme.style?.textStyle
              ?.resolve(const {})?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
      expect(theme.snackBarTheme.contentTextStyle?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
