import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/app_typography.dart';

/// [AppTypography.display] is a standalone GoogleFonts call — it sits
/// outside the ThemeData/textTheme tree app_theme_style_test.dart already
/// covers, so it needs its own guard against the same missing-Bengali-glyph
/// regression. See AppTypography.bengaliFallback for why this matters.
///
/// The styles read the theme (which face, which default color), so each is
/// resolved through a real [BuildContext] under a theme carrying just the
/// palette — the same lookup the app does, without building a full ThemeData.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Runs [read] against a context whose theme carries [palette], with
  /// google_fonts' unloadable-font complaint swallowed — same reasoning as
  /// `themeFor` in app_theme_style_test.dart.
  Future<T> resolve<T>(
    WidgetTester tester,
    AppColorPalette palette,
    T Function(BuildContext) read,
  ) async {
    late T result;
    // A bare `Theme`, not `MaterialApp`: MaterialApp animates theme changes,
    // so a second pumpWidget would still resolve the previous palette.
    await tester.pumpWidget(Theme(
      data: ThemeData(extensions: [palette]),
      child: Builder(builder: (context) {
        runZonedGuarded(
          () => result = read(context),
          (error, stack) {
            if (!error.toString().contains('google_fonts') &&
                !error
                    .toString()
                    .contains('was not found in the application assets')) {
              throw error;
            }
          },
        );
        return const SizedBox();
      }),
    ));
    return result;
  }

  group('AppTypography.display', () {
    testWidgets('carries the Bengali fallback on every color mode, mono or proportional',
        (tester) async {
      for (final mode in AppColorMode.values) {
        final style = await resolve(tester,
            AppColorPalette.forMode(mode, Brightness.dark),
            (c) => AppTypography.display(c, 20));
        expect(style.fontFamilyFallback,
            contains(AppTypography.bengaliFallback.single),
            reason: '$mode');
      }
    });

    testWidgets('sets Retro in a monospace face and every other mode in Space Grotesk',
        (tester) async {
      for (final mode in AppColorMode.values) {
        final style = await resolve(tester,
            AppColorPalette.forMode(mode, Brightness.light),
            (c) => AppTypography.display(c, 20));
        final isMono = style.fontFamily!.contains('IBMPlexMono');
        expect(isMono, mode == AppColorMode.retro, reason: '$mode');
      }
    });

    testWidgets('defaults its color to the palette\'s primary text', (tester) async {
      const palette = AppColorPalette.carbonMonoDark;
      final style = await resolve(
          tester, palette, (c) => AppTypography.display(c, 20));
      expect(style.color, palette.textPrimary);
    });
  });

  group('cockpit tokens', () {
    testWidgets('hold the live-ride legibility floor (labels 14, values 20)',
        (tester) async {
      final label = await resolve(tester, AppColorPalette.carbonMonoDark,
          (c) => AppTypography.cockpitLabel(c));
      final value = await resolve(tester, AppColorPalette.carbonMonoDark,
          (c) => AppTypography.cockpitValue(c));
      expect(label.fontSize, greaterThanOrEqualTo(14));
      expect(value.fontSize, greaterThanOrEqualTo(20));
    });
  });
}
