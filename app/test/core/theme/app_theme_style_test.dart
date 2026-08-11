import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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

    test('only Retro squares its corners off', () {
      // Retro is the one skin that is a shape change as well as a palette
      // (see AppColorPalette.retro). If another skin starts returning zero
      // radii, either it copied Retro's branch or the shared
      // AppDimensions radii were flattened for everyone.
      double cardRadius(AppThemeStyle style) {
        final shape = themeFor(style).cardTheme.shape;
        return ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
            .topLeft
            .x;
      }

      expect(cardRadius(AppThemeStyle.retro), 0);
      for (final style in AppThemeStyle.values) {
        if (style == AppThemeStyle.retro) continue;
        expect(cardRadius(style), greaterThan(0), reason: '$style');
      }
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
