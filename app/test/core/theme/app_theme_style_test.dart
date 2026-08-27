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

    test('the newly-authored light/dark companions clear AA contrast for UI components (3:1)', () {
      // 3:1 is WCAG AA's bar for large text/UI components (icons, button
      // fills, chart lines) — what `primary` is actually used for, as
      // opposed to 4.5:1's small-body-text bar. Scoped to the SIX new
      // companion palettes this change authored (carbonMonoLight,
      // editorialDark, nocturneLight, trailSocialLight, calmingDark,
      // analystBlueLight — Retro has no accent hue to check), each
      // deliberately darkened/lightened for this — not asserted against the
      // four original, unmodified light/dark palettes, some of which
      // (Editorial's blue at ~4.0:1, Calming's sage at ~2.4:1) already
      // shipped below this bar and are out of scope for this change to fix.
      final newCompanions = {
        'carbonMonoLight': AppColorPalette.carbonMonoLight,
        'editorialDark': AppColorPalette.editorialDark,
        'nocturneLight': AppColorPalette.nocturneLight,
        'trailSocialLight': AppColorPalette.trailSocialLight,
        'calmingDark': AppColorPalette.calmingDark,
        'analystBlueLight': AppColorPalette.analystBlueLight,
      };
      newCompanions.forEach((name, p) {
        final bg = p.background.computeLuminance();
        final fg = p.primary.computeLuminance();
        final contrast = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
        expect(contrast, greaterThanOrEqualTo(3.0),
            reason: '$name: primary on background is only '
                '${contrast.toStringAsFixed(2)}:1');
      });
    });

    test('secondary is a distinct accent from primary, in every combination', () {
      // Several directions specify only one true accent; the rest derive a
      // second one. A combination where the two collapse to the same value
      // silently flattens every UI that uses them to distinguish two things.
      // Retro is exempt by design — see the dedicated Retro group below.
      for (final (mode, brightness) in allCombos) {
        if (mode == AppColorMode.retro) continue;
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
      expect(AppAppearance.defaultAppearance.colorMode, AppColorMode.calming);
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

  group('AppDimensions, the shape facade', () {
    tearDown(() => AppDimensions.apply(AppShapeProfile.boxy));

    test('apply() swaps every radius at once', () {
      AppDimensions.apply(AppShapeProfile.curvy);
      expect(AppDimensions.radiusSm, AppShapeProfile.curvy.radiusSm);
      expect(AppDimensions.radiusMd, AppShapeProfile.curvy.radiusMd);
      expect(AppDimensions.radiusLg, AppShapeProfile.curvy.radiusLg);
      expect(AppDimensions.radiusXl, AppShapeProfile.curvy.radiusXl);
      expect(AppDimensions.radiusFull, AppShapeProfile.curvy.radiusFull);
      expect(AppDimensions.shape, same(AppShapeProfile.curvy));
    });

    test('apply() swaps rule weights and control metrics too', () {
      AppDimensions.apply(AppShapeProfile.curvy);
      expect(AppDimensions.outlineWidth, 1);
      expect(AppDimensions.controlHeight, AppShapeProfile.curvy.controlHeight);
      expect(AppDimensions.fieldPaddingH, AppShapeProfile.curvy.fieldPaddingH);
      expect(AppDimensions.fieldPaddingV, AppShapeProfile.curvy.fieldPaddingV);
      AppDimensions.apply(AppShapeProfile.boxy);
      expect(AppDimensions.controlHeight, AppShapeProfile.boxy.controlHeight);
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

    test('the card radius is the applied vibe\'s, not a shared constant', () {
      // AppTheme.build reads AppDimensions, which is a facade over whichever
      // AppShapeProfile was last applied — so the theme's shape follows the
      // *applied* profile, not an argument to build(). Applying it first is
      // what a real appearance switch does (see
      // AppearanceNotifier._applyTokens); getting that wrong is how a rider
      // ends up with the previous vibe's corners.
      double cardRadius(AppShapeVibe vibe) {
        AppDimensions.apply(AppShapeProfile.forVibe(vibe));
        final appearance = AppAppearance(
            colorMode: AppColorMode.carbonMono, shapeVibe: vibe, brightness: Brightness.dark);
        final shape = themeFor(appearance).cardTheme.shape;
        return ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
            .topLeft
            .x;
      }

      for (final vibe in AppShapeVibe.values) {
        expect(cardRadius(vibe), AppShapeProfile.forVibe(vibe).radiusXl, reason: '$vibe');
      }
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
    });

    test('Retro respects the applied vibe like every other color mode', () {
      // Retro's identity is now entirely in its palette (monochrome, an
      // ink-strength border, monospace type) — NOT in a fixed shape. Boxy
      // Retro and Curvy Retro must differ in corner radius exactly the way
      // any other color mode's two vibes would.
      for (final vibe in AppShapeVibe.values) {
        AppDimensions.apply(AppShapeProfile.forVibe(vibe));
        final appearance = AppAppearance(
            colorMode: AppColorMode.retro, shapeVibe: vibe, brightness: Brightness.light);
        final card = themeFor(appearance).cardTheme.shape! as RoundedRectangleBorder;
        expect((card.borderRadius as BorderRadius).topLeft.x,
            AppShapeProfile.forVibe(vibe).radiusXl,
            reason: '$vibe');
      }
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
    });

    test('Retro is monospace regardless of vibe or brightness', () {
      for (final vibe in AppShapeVibe.values) {
        for (final brightness in Brightness.values) {
          final appearance =
              AppAppearance(colorMode: AppColorMode.retro, shapeVibe: vibe, brightness: brightness);
          AppTypography.applyStyle(appearance.colorMode);
          expect(AppTypography.isMono, isTrue, reason: '$vibe/$brightness');
        }
      }
      addTearDown(() => AppTypography.applyStyle(AppColorMode.carbonMono));
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

  group('Retro, the black-and-white terminal color mode', () {
    void checkMonochrome(AppColorPalette retro, String label) {
      // The direction is "no chroma anywhere". A token that drifts back to a
      // hue (a copy-pasted red danger, say) is the failure this catches, and
      // it is invisible in review because a slightly-red near-black still
      // reads as black in a diff.
      final tokens = <String, Color>{
        'background': retro.background,
        'surface': retro.surface,
        'border': retro.border,
        'surfaceVariant': retro.surfaceVariant,
        'ink': retro.ink,
        'onInk': retro.onInk,
        'onInkMuted': retro.onInkMuted,
        'primary': retro.primary,
        'primaryHighlight': retro.primaryHighlight,
        'primaryDark': retro.primaryDark,
        'secondary': retro.secondary,
        'secondaryLight': retro.secondaryLight,
        'attention': retro.attention,
        'success': retro.success,
        'warning': retro.warning,
        'danger': retro.danger,
        'textPrimary': retro.textPrimary,
        'textSecondary': retro.textSecondary,
        'textTertiary': retro.textTertiary,
        'shimmerBase': retro.shimmerBase,
        'shimmerHighlight': retro.shimmerHighlight,
      };

      tokens.forEach((name, color) {
        final channels = [color.r, color.g, color.b];
        final spread = channels.reduce(max) - channels.reduce(min);
        // Paper white/near-black isn't pure #FFF/#000 and carries a trace of
        // warmth, so a few percent of channel spread is the design. A real
        // hue is an order of magnitude away.
        expect(spread, lessThan(0.05),
            reason: '$label.$name is not neutral: $color (channel spread $spread)');
      });
    }

    test('retroLight is strictly monochrome', () =>
        checkMonochrome(AppColorPalette.retroLight, 'retroLight'));
    test('retroDark is strictly monochrome', () =>
        checkMonochrome(AppColorPalette.retroDark, 'retroDark'));

    test('severity is encoded in value, since it cannot be in hue', () {
      // danger louder than warning louder than success — see the palette's
      // note on the grey ramp standing in for red/amber/green. retroDark
      // inverts the DIRECTION (danger is the brightest mark on black, not
      // the darkest), so each palette is checked against its own polarity.
      final light = AppColorPalette.retroLight;
      expect(light.danger.computeLuminance(), lessThan(light.warning.computeLuminance()));
      expect(light.warning.computeLuminance(), lessThan(light.success.computeLuminance()));

      final dark = AppColorPalette.retroDark;
      expect(dark.danger.computeLuminance(), greaterThan(dark.warning.computeLuminance()));
      expect(dark.warning.computeLuminance(), greaterThan(dark.success.computeLuminance()));
    });

    test('keeps a full-strength rule rather than a hairline tint', () {
      // The heavy rule is the direction; softening it to a tint of the
      // background would leave a bland theme. Both palettes' border matches
      // their own `ink` exactly — retroLight's is black-on-white, retroDark's
      // inverts `ink` itself to be the pale tone, so the rule is still the
      // boldest mark available either way. See the palette's doc comment.
      expect(AppColorPalette.retroLight.border.toARGB32(),
          AppColorPalette.retroLight.ink.toARGB32());
      expect(AppColorPalette.retroDark.border.toARGB32(),
          AppColorPalette.retroDark.ink.toARGB32());
    });
  });
}
