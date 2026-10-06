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

/// The appearance catalogue's structural invariants — Vibe (shape), Color
/// mode, and Brightness are three independent axes now, so this covers all
/// 14 (colorMode, brightness) palette combinations and both shape vibes,
/// rather than one flat list of skins.
///
/// `AppColorPalette.forMode` is an exhaustive switch, so "every combination
/// has a palette" is already a compile error rather than a test failure.
/// What isn't caught by the compiler is a palette that was added by
/// copy-pasting another one and only half-edited — which reads as working
/// right up until a rider picks it and gets the wrong accent, or dark text
/// on a dark base.
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

  /// Every (colorMode, brightness) combination — the full palette catalogue.
  final allCombos = [
    for (final mode in AppColorMode.values)
      for (final brightness in Brightness.values) (mode, brightness),
  ];

  /// [AppTheme.build] with google_fonts' unloadable-font complaint swallowed.
  ThemeData themeFor(AppAppearance appearance) {
    late ThemeData theme;
    runZonedGuarded(
      () => theme = AppTheme.build(appearance),
      (error, stack) {
        // Anything that isn't the known font-asset gripe is a real failure
        // and must not be silently eaten.
        if (!error.toString().contains('google_fonts') &&
            !error.toString().contains('was not found in the application assets')) {
          throw error;
        }
      },
    );
    return theme;
  }

  group('AppColorPalette catalogue', () {
    test('every (colorMode, brightness) combination resolves to a palette', () {
      for (final (mode, brightness) in allCombos) {
        expect(AppColorPalette.forMode(mode, brightness), isNotNull,
            reason: '$mode/$brightness');
      }
    });

    test('no two combinations share a background/primary pair', () {
      // The copy-paste guard: two combinations with the same base and accent
      // are the same identity under two names, whatever else differs.
      final seen = <String, (AppColorMode, Brightness)>{};
      for (final (mode, brightness) in allCombos) {
        final p = AppColorPalette.forMode(mode, brightness);
        final key = '${p.background.toARGB32()}/${p.primary.toARGB32()}';
        expect(seen[key], isNull,
            reason: '$mode/$brightness is visually identical to ${seen[key]}');
        seen[key] = (mode, brightness);
      }
    });

    test('isDark agrees with both the requested brightness and the palette\'s own background luminance', () {
      // isDark drives ThemeData.brightness, the ColorScheme variant, the
      // status-bar icon color and which app mark is shown. A palette that
      // lies about it renders black system icons on a black bar.
      for (final (mode, brightness) in allCombos) {
        final p = AppColorPalette.forMode(mode, brightness);
        expect(p.isDark, brightness == Brightness.dark, reason: '$mode/$brightness');
        expect(p.isDark, p.background.computeLuminance() < 0.5,
            reason: '$mode/$brightness declares isDark=${p.isDark} but its '
                'background luminance is ${p.background.computeLuminance()}');
      }
    });

    test('body text stays readable against its own background', () {
      // Not a full WCAG audit — just the failure that a half-edited palette
      // actually produces: primary text inherited from the opposite
      // brightness's sibling.
      for (final (mode, brightness) in allCombos) {
        final p = AppColorPalette.forMode(mode, brightness);
        final bg = p.background.computeLuminance();
        final fg = p.textPrimary.computeLuminance();
        final contrast = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
        expect(contrast, greaterThan(7.0),
            reason: '$mode/$brightness: textPrimary on background is only '
                '${contrast.toStringAsFixed(1)}:1');
      }
    });

    test('the light/dark companions clear AA contrast for UI components (3:1)', () {
      final companions = {
        'sportLight': AppColorPalette.sportLight,
        'dailyDark': AppColorPalette.dailyDark,
        'adventureLight': AppColorPalette.adventureLight,
      };
      companions.forEach((name, p) {
        final bg = p.background.computeLuminance();
        final fg = p.primary.computeLuminance();
        final contrast = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
        expect(contrast, greaterThanOrEqualTo(3.0),
            reason: '$name: primary on background is only '
                '${contrast.toStringAsFixed(2)}:1');
      });
    });

    test('secondary is a distinct accent from primary, in every combination', () {
      for (final (mode, brightness) in allCombos) {
        final p = AppColorPalette.forMode(mode, brightness);
        expect(p.secondary.toARGB32(), isNot(p.primary.toARGB32()),
            reason: '$mode/$brightness');
      }
    });
  });

  group('AppShapeProfile catalogue', () {
    test('every vibe resolves to a profile', () {
      // forVibe is exhaustive, so this is a compile-time guarantee; asserted
      // anyway so the intent survives a refactor that adds a default branch.
      for (final vibe in AppShapeVibe.values) {
        expect(AppShapeProfile.forVibe(vibe), isNotNull, reason: '$vibe');
      }
    });

    test('Boxy and Curvy are actually distinguishable', () {
      // The point of a shape vibe is that a rider can see it. A "curvy"
      // profile two pixels off boxy reads as a rendering artifact, which is
      // the failure this catches.
      expect(AppShapeProfile.curvy.radiusMd,
          greaterThan(AppShapeProfile.boxy.radiusMd * 3));
      expect(AppShapeProfile.curvy.radiusXl,
          greaterThan(AppShapeProfile.boxy.radiusXl * 2));
    });

    test('radii are ordered sm ≤ md ≤ lg ≤ xl within every profile', () {
      for (final vibe in AppShapeVibe.values) {
        final s = AppShapeProfile.forVibe(vibe);
        expect(s.radiusSm, lessThanOrEqualTo(s.radiusMd), reason: '$vibe');
        expect(s.radiusMd, lessThanOrEqualTo(s.radiusLg), reason: '$vibe');
        expect(s.radiusLg, lessThanOrEqualTo(s.radiusXl), reason: '$vibe');
      }
    });

    test('Boxy keeps the historical instrument-panel radii exactly', () {
      // Regression guard: riders who never touch the new controls must get
      // pixel-identical corners to what the app always had.
      expect(AppShapeProfile.boxy.radiusSm, 2);
      expect(AppShapeProfile.boxy.radiusMd, 2);
      expect(AppShapeProfile.boxy.radiusLg, 4);
      expect(AppShapeProfile.boxy.radiusXl, 6);
      expect(AppShapeProfile.boxy.radiusFull, 4);
      expect(AppShapeProfile.boxy.outlineWidth, 1);
      expect(AppShapeProfile.boxy.controlHeight, 52);
    });

    test('the default appearance is Calming, Curvy, Light', () {
      // The fallback for an unknown persisted preference, and what every new
      // install/account starts on. If it ever resolves to another
      // combination, every rider who never touched Settings gets a silent
      // restyle.
      expect(AppAppearance.defaultAppearance.colorMode, AppColorMode.daily);
      expect(AppAppearance.defaultAppearance.shapeVibe, AppShapeVibe.curvy);
      expect(AppAppearance.defaultAppearance.brightness, Brightness.light);
      expect(AppShapeProfile.forVibe(AppAppearance.defaultAppearance.shapeVibe),
          same(AppShapeProfile.curvy));
    });

    test('Curvy gets a true pill for the full-radius token', () {
      // radiusFull backs chips, progress bars and badges. A 4px "pill" on
      // Curvy is the tell that the profile was copied from Boxy.
      expect(AppShapeProfile.curvy.radiusFull, greaterThanOrEqualTo(100));
    });

    test('spacing and chrome heights are not part of an appearance', () {
      // An appearance changes how the app looks, not where things are: the
      // padding scale and the nav/app-bar heights stay compile-time
      // constants, so no combination can reflow a screen.
      expect(AppDimensions.paddingSm, 8);
      expect(AppDimensions.paddingMd, 16);
      expect(AppDimensions.paddingLg, 24);
      expect(AppDimensions.paddingXl, 32);
      expect(AppDimensions.bottomNavHeight, 72);
      expect(AppDimensions.appBarHeight, 64);
    });
  });

  group('appearance tokens travel on the theme', () {
    test('AppTheme.build registers the palette and shape for that appearance', () {
      // This is what `context.palette` / `context.shape` resolve through, so
      // it is the contract every widget depends on: the theme carries exactly
      // the tokens for the appearance it was built from — nothing left over
      // from whatever was built before it.
      for (final (mode, brightness) in allCombos) {
        for (final vibe in AppShapeVibe.values) {
          final theme = themeFor(AppAppearance(
              colorMode: mode, shapeVibe: vibe, brightness: brightness));
          expect(theme.extension<AppColorPalette>(),
              same(AppColorPalette.forMode(mode, brightness)),
              reason: '$mode/$brightness');
          expect(theme.extension<AppShapeProfile>(),
              same(AppShapeProfile.forVibe(vibe)),
              reason: '$vibe');
        }
      }
    });

    test('the palette cross-fades colors and flips its flags at the halfway point', () {
      const a = AppColorPalette.sportDark;
      const b = AppColorPalette.dailyLight;
      expect(a.lerp(b, 0).primary, a.primary);
      expect(a.lerp(b, 0).background, a.background);
      expect(a.lerp(b, 1).primary, b.primary);
      expect(a.lerp(b, 0.5).primary, Color.lerp(a.primary, b.primary, 0.5));
      expect(a.lerp(b, 0.49).isDark, isTrue);
      expect(a.lerp(b, 0.5).isDark, isFalse);
    });

    test('the shape profile does not tween — radiusFull is 999 on Curvy', () {
      // Interpolating boxy -> curvy would sweep every pill through absurd
      // radii mid-animation, so the whole profile flips at the halfway point.
      const boxy = AppShapeProfile.boxy;
      const curvy = AppShapeProfile.curvy;
      expect(boxy.lerp(curvy, 0.49), same(boxy));
      expect(boxy.lerp(curvy, 0.5), same(curvy));
      expect(boxy.lerp(null, 1), same(boxy));
    });

    test('copyWith overrides only what it is given', () {
      final p = AppColorPalette.dailyLight.copyWith(primary: const Color(0xFF123456));
      expect(p.primary, const Color(0xFF123456));
      expect(p.background, AppColorPalette.dailyLight.background);
      expect(p.monoDisplay, AppColorPalette.dailyLight.monoDisplay);
      final s = AppShapeProfile.boxy.copyWith(radiusMd: 9);
      expect(s.radiusMd, 9);
      expect(s.radiusSm, AppShapeProfile.boxy.radiusSm);
    });
  });

  group('AppTheme.build', () {
    test('brightness follows the requested Brightness, not the color mode', () {
      for (final (mode, brightness) in allCombos) {
        final appearance = AppAppearance(
            colorMode: mode, shapeVibe: AppShapeVibe.boxy, brightness: brightness);
        final theme = themeFor(appearance);
        expect(theme.brightness, brightness, reason: '$mode/$brightness');
      }
    });

    test('the card radius is the requested vibe\'s, not a shared constant', () {
      double cardRadius(AppShapeVibe vibe) {
        final appearance = AppAppearance(
            colorMode: AppColorMode.sport, shapeVibe: vibe, brightness: Brightness.dark);
        final shape = themeFor(appearance).cardTheme.shape;
        return ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
            .topLeft
            .x;
      }

      for (final vibe in AppShapeVibe.values) {
        expect(cardRadius(vibe), AppShapeProfile.forVibe(vibe).radiusXl, reason: '$vibe');
      }
    });

    test('no mode is monospace display by default', () {
      for (final mode in AppColorMode.values) {
        for (final vibe in AppShapeVibe.values) {
          for (final brightness in Brightness.values) {
            final palette = themeFor(AppAppearance(
                    colorMode: mode, shapeVibe: vibe, brightness: brightness))
                .extension<AppColorPalette>()!;
            expect(palette.monoDisplay, isFalse,
                reason: '$mode/$vibe/$brightness');
          }
        }
      }
    });

    test('every named text style carries the Bengali fallback', () {
      // None of IBM Plex Mono, IBM Plex Sans, or Space Grotesk ship Bengali
      // glyphs (see AppTypography.bengaliFallback), so every style in the
      // theme needs the bundled fallback appended or Bangla text silently
      // drops to whatever face the platform substitutes.
      for (final (mode, brightness) in allCombos) {
        final appearance =
            AppAppearance(colorMode: mode, shapeVibe: AppShapeVibe.boxy, brightness: brightness);
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
              reason: '$mode/$brightness');
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
              ?.resolve(const {})
              ?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
      expect(
          theme.outlinedButtonTheme.style?.textStyle
              ?.resolve(const {})
              ?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
      expect(theme.snackBarTheme.contentTextStyle?.fontFamilyFallback,
          contains(AppTypography.bengaliFallback.single));
    });
  });

  group('Sport mode (Lime Carbon)', () {
    test('sportDark uses high-contrast pitch carbon background with electric lime', () {
      expect(AppColorPalette.sportDark.background, const Color(0xFF0D0D0D));
      expect(AppColorPalette.sportDark.primary, const Color(0xFFC8FF3D));
      expect(AppColorPalette.sportDark.secondary, const Color(0xFFD633FF));
      expect(AppColorPalette.sportDark.isDark, isTrue);
    });

    test('sportLight uses technical daylight background with deep olive', () {
      expect(AppColorPalette.sportLight.background, const Color(0xFFF7F8F4));
      expect(AppColorPalette.sportLight.primary, const Color(0xFF5C7A1E));
      expect(AppColorPalette.sportLight.secondary, const Color(0xFFA82BC0));
      expect(AppColorPalette.sportLight.isDark, isFalse);
    });
  });

  group('Adventure mode (Analyst Blue & Nocturne)', () {
    test('adventureDark uses midnight navy with cyan telemetry', () {
      expect(AppColorPalette.adventureDark.background, const Color(0xFF0B1C2C));
      expect(AppColorPalette.adventureDark.primary, const Color(0xFF25C0E6));
      expect(AppColorPalette.adventureDark.secondary, const Color(0xFFF3906D));
      expect(AppColorPalette.adventureDark.isDark, isTrue);
    });

    test('adventureLight uses glacier ice background with console cyan', () {
      expect(AppColorPalette.adventureLight.background, const Color(0xFFF2F7FA));
      expect(AppColorPalette.adventureLight.primary, const Color(0xFF0A7F9E));
      expect(AppColorPalette.adventureLight.secondary, const Color(0xFFC15A38));
      expect(AppColorPalette.adventureLight.isDark, isFalse);
    });
  });

  group('Daily mode (Calm & Collected)', () {
    test('dailyLight uses warm cream with sage green', () {
      expect(AppColorPalette.dailyLight.background, const Color(0xFFF8F5EF));
      expect(AppColorPalette.dailyLight.primary, const Color(0xFF537D5C));
      expect(AppColorPalette.dailyLight.secondary, const Color(0xFFBD8D65));
      expect(AppColorPalette.dailyLight.isDark, isFalse);
    });

    test('dailyDark uses warm charcoal with soft sage', () {
      expect(AppColorPalette.dailyDark.background, const Color(0xFF17170F));
      expect(AppColorPalette.dailyDark.primary, const Color(0xFFA8C7AD));
      expect(AppColorPalette.dailyDark.secondary, const Color(0xFFDBB597));
      expect(AppColorPalette.dailyDark.isDark, isTrue);
    });
  });
}
