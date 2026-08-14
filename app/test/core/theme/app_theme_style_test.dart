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

/// The skin catalogue's structural invariants.
///
/// `AppColorPalette.forStyle` is an exhaustive switch, so "every style has a
/// palette" is already a compile error rather than a test failure. What isn't
/// caught by the compiler is a palette that was added by copy-pasting another
/// one and only half-edited — which reads as a working skin right up until a
/// rider picks it and gets the wrong accent, or dark text on a dark base.
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
  ThemeData themeFor(AppThemeStyle style) {
    late ThemeData theme;
    runZonedGuarded(
      () => theme = AppTheme.build(style),
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
    test('every style resolves to a palette', () {
      for (final style in AppThemeStyle.values) {
        expect(AppColorPalette.forStyle(style), isNotNull, reason: '$style');
      }
    });

    test('no two skins share a background/primary pair', () {
      // The copy-paste guard: two skins with the same base and accent are the
      // same skin under two names, whatever else differs.
      final seen = <String, AppThemeStyle>{};
      for (final style in AppThemeStyle.values) {
        final p = AppColorPalette.forStyle(style);
        final key = '${p.background.toARGB32()}/${p.primary.toARGB32()}';
        expect(seen[key], isNull,
            reason: '$style is visually identical to ${seen[key]}');
        seen[key] = style;
      }
    });

    test('isDark agrees with the palette\'s own background luminance', () {
      // isDark drives ThemeData.brightness, the ColorScheme variant, the
      // status-bar icon color and which app mark is shown. A skin that lies
      // about it renders black system icons on a black bar.
      for (final style in AppThemeStyle.values) {
        final p = AppColorPalette.forStyle(style);
        expect(p.isDark, p.background.computeLuminance() < 0.5,
            reason: '$style declares isDark=${p.isDark} but its background '
                'luminance is ${p.background.computeLuminance()}');
      }
    });

    test('body text stays readable against the skin\'s own background', () {
      // Not a full WCAG audit — just the failure that a half-edited palette
      // actually produces: primary text inherited from a skin of the opposite
      // brightness.
      for (final style in AppThemeStyle.values) {
        final p = AppColorPalette.forStyle(style);
        final bg = p.background.computeLuminance();
        final fg = p.textPrimary.computeLuminance();
        final contrast = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
        expect(contrast, greaterThan(7.0),
            reason: '$style: textPrimary on background is only '
                '${contrast.toStringAsFixed(1)}:1');
      }
    });

    test('secondary is a distinct accent from primary, per skin', () {
      // Several directions in the source deck specify only one accent; the
      // rest of the palette derives a second one. A skin where the two
      // collapse to the same value silently flattens every UI that uses them
      // to distinguish two things.
      for (final style in AppThemeStyle.values) {
        final p = AppColorPalette.forStyle(style);
        expect(p.secondary.toARGB32(), isNot(p.primary.toARGB32()),
            reason: '$style');
      }
    });
  });

  group('AppShapeProfile catalogue', () {
    test('every style resolves to a shape profile', () {
      // forStyle is exhaustive, so this is a compile-time guarantee; asserted
      // anyway so the intent survives a refactor that adds a default branch.
      for (final style in AppThemeStyle.values) {
        expect(AppShapeProfile.forStyle(style), isNotNull, reason: '$style');
      }
    });

    test('the three profiles are actually distinguishable', () {
      // The point of per-skin shape is that a rider can see it. A "rounded"
      // profile two pixels off the boxy one reads as a rendering artifact,
      // which is the failure this catches.
      expect(AppShapeProfile.rounded.radiusMd,
          greaterThan(AppShapeProfile.boxy.radiusMd * 3));
      expect(AppShapeProfile.rounded.radiusXl,
          greaterThan(AppShapeProfile.boxy.radiusXl * 2));
      expect(AppShapeProfile.terminal.radiusXl, 0);
    });

    test('radii are ordered sm ≤ md ≤ lg ≤ xl within every profile', () {
      // A half-edited profile (lg smaller than md, say) draws a card with
      // tighter corners than the chip inside it — visible, but only if you
      // happen to apply that one skin.
      for (final style in AppThemeStyle.values) {
        final s = AppShapeProfile.forStyle(style);
        expect(s.radiusSm, lessThanOrEqualTo(s.radiusMd), reason: '$style');
        expect(s.radiusMd, lessThanOrEqualTo(s.radiusLg), reason: '$style');
        expect(s.radiusLg, lessThanOrEqualTo(s.radiusXl), reason: '$style');
      }
    });

    test('boxy skins keep the historical instrument-panel radii exactly', () {
      // The skins that stay boxy must be pixel-identical to what riders
      // already have — this is the regression guard on "no visual change for
      // the five dashboard/editorial directions".
      expect(AppShapeProfile.boxy.radiusSm, 2);
      expect(AppShapeProfile.boxy.radiusMd, 2);
      expect(AppShapeProfile.boxy.radiusLg, 4);
      expect(AppShapeProfile.boxy.radiusXl, 6);
      expect(AppShapeProfile.boxy.radiusFull, 4);
      expect(AppShapeProfile.boxy.outlineWidth, 1);
      expect(AppShapeProfile.boxy.controlHeight, 52);
    });

    test('Carbon Mono, the default skin, is boxy', () {
      // The app's primary design language, and the fallback for an unknown
      // persisted preference. If it ever resolves to another profile, every
      // rider who never picked a skin gets a silent restyle.
      expect(AppShapeProfile.forStyle(AppThemeStyle.carbonMono),
          same(AppShapeProfile.boxy));
    });

    test('only Retro gets the terminal profile', () {
      for (final style in AppThemeStyle.values) {
        final isTerminal =
            AppShapeProfile.forStyle(style) == AppShapeProfile.terminal;
        expect(isTerminal, style == AppThemeStyle.retro, reason: '$style');
      }
    });

    test('rounded skins get a true pill for the full-radius token', () {
      // radiusFull backs chips, progress bars and badges. On a rounded skin a
      // 4px "pill" is the tell that the profile was copied from the boxy one.
      for (final style in AppThemeStyle.values) {
        final s = AppShapeProfile.forStyle(style);
        if (s != AppShapeProfile.rounded) continue;
        expect(s.radiusFull, greaterThanOrEqualTo(100), reason: '$style');
      }
    });

    test('spacing and chrome heights are not part of a skin', () {
      // A skin changes how the app looks, not where things are: the padding
      // scale and the nav/app-bar heights stay compile-time constants, so no
      // skin can reflow a screen. This is the guard on "no hierarchy change".
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
      AppDimensions.apply(AppShapeProfile.rounded);
      expect(AppDimensions.radiusSm, AppShapeProfile.rounded.radiusSm);
      expect(AppDimensions.radiusMd, AppShapeProfile.rounded.radiusMd);
      expect(AppDimensions.radiusLg, AppShapeProfile.rounded.radiusLg);
      expect(AppDimensions.radiusXl, AppShapeProfile.rounded.radiusXl);
      expect(AppDimensions.radiusFull, AppShapeProfile.rounded.radiusFull);
      expect(AppDimensions.shape, same(AppShapeProfile.rounded));
    });

    test('apply() swaps rule weights and control metrics too', () {
      AppDimensions.apply(AppShapeProfile.terminal);
      expect(AppDimensions.outlineWidth, 2);
      expect(AppDimensions.emphasisOutlineWidth, 2);
      AppDimensions.apply(AppShapeProfile.rounded);
      expect(AppDimensions.outlineWidth, 1);
      expect(AppDimensions.controlHeight, AppShapeProfile.rounded.controlHeight);
      expect(AppDimensions.fieldPaddingH, AppShapeProfile.rounded.fieldPaddingH);
      expect(AppDimensions.fieldPaddingV, AppShapeProfile.rounded.fieldPaddingV);
    });
  });

  group('AppTheme.build', () {
    test('brightness follows each skin\'s palette, not its identity', () {
      for (final style in AppThemeStyle.values) {
        final palette = AppColorPalette.forStyle(style);
        final theme = themeFor(style);
        expect(theme.brightness,
            palette.isDark ? Brightness.dark : Brightness.light,
            reason: '$style');
      }
    });

    test('the card radius is the applied skin\'s, not a shared constant', () {
      // AppTheme.build reads AppDimensions, which is a facade over whichever
      // AppShapeProfile was last applied — so the theme's shape follows the
      // *applied* skin, not the style argument. Applying each skin's profile
      // before building is what a real skin switch does (see
      // ThemeStyleNotifier._applyTokens); getting that wrong is how a rider
      // ends up with the previous skin's corners.
      double cardRadius(AppThemeStyle style) {
        AppDimensions.apply(AppShapeProfile.forStyle(style));
        final shape = themeFor(style).cardTheme.shape;
        return ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
            .topLeft
            .x;
      }

      for (final style in AppThemeStyle.values) {
        expect(cardRadius(style), AppShapeProfile.forStyle(style).radiusXl,
            reason: '$style');
      }
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
    });

    test('Retro squares its corners off and doubles its rules', () {
      // Retro is the skin whose shape *is* the direction — square corners and
      // the heavy ink rule AppColorPalette.retro's border supplies. If it
      // starts drawing a radius, it picked up another skin's profile.
      AppDimensions.apply(AppShapeProfile.forStyle(AppThemeStyle.retro));
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
      final theme = themeFor(AppThemeStyle.retro);

      final card = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect((card.borderRadius as BorderRadius).topLeft.x, 0);
      expect(card.side.width, 2);

      final button =
          theme.elevatedButtonTheme.style!.shape!.resolve(const {})!
              as RoundedRectangleBorder;
      expect((button.borderRadius as BorderRadius).topLeft.x, 0);
    });

    test('every named text style carries the Bengali fallback', () {
      // None of IBM Plex Mono, IBM Plex Sans, or Space Grotesk ship Bengali
      // glyphs (see AppTypography.bengaliFallback), so every style in the
      // theme needs the bundled fallback appended or Bangla text silently
      // drops to whatever face the platform substitutes.
      for (final style in AppThemeStyle.values) {
        final textTheme = themeFor(style).textTheme;
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
              reason: '$style');
        }
      }
    });

    test('the standalone text styles outside textTheme carry it too', () {
      // App bar title, button labels and the snackbar build their TextStyle
      // directly from GoogleFonts rather than through textTheme, so
      // textTheme's blanket .apply() never reaches them — each needs its own
      // fontFamilyFallback, verified here so a future edit that adds another
      // standalone GoogleFonts.xxx() call without it fails loudly.
      final theme = themeFor(AppThemeStyle.carbonMono);
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

  group('Retro, the black-and-white terminal skin', () {
    final retro = AppColorPalette.retro;

    test('is strictly monochrome — every token is a neutral grey', () {
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
        // Paper white isn't #FFFFFF and its greys carry a trace of that
        // warmth, so a few percent of channel spread is the design. A real
        // hue is an order of magnitude away — the mustard and rust this
        // palette replaced sat at 0.71 and 0.56.
        expect(spread, lessThan(0.05),
            reason: '$name is not neutral: $color (channel spread $spread)');
      });
    });

    test('severity is encoded in value, since it cannot be in hue', () {
      // danger louder than warning louder than success — see the palette's
      // note on the grey ramp standing in for red/amber/green.
      expect(retro.danger.computeLuminance(),
          lessThan(retro.warning.computeLuminance()));
      expect(retro.warning.computeLuminance(),
          lessThan(retro.success.computeLuminance()));
    });

    test('keeps a full-strength ink border rather than a hairline tint', () {
      // The heavy black rule is the direction; softening it to a tint of the
      // background would leave a bland light theme.
      expect(retro.border.toARGB32(), retro.ink.toARGB32());
    });
  });
}
