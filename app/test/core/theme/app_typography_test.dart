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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// [AppTypography.display] with google_fonts' unloadable-font complaint
  /// swallowed — same reasoning as `themeFor` in app_theme_style_test.dart.
  TextStyle displayFor(AppColorMode colorMode) {
    AppTypography.applyStyle(colorMode);
    late TextStyle result;
    runZonedGuarded(
      () => result = AppTypography.display(20),
      (error, stack) {
        if (!error.toString().contains('google_fonts') &&
            !error.toString().contains('was not found in the application assets')) {
          throw error;
        }
      },
    );
    return result;
  }

  tearDown(() => AppTypography.applyStyle(AppColorMode.carbonMono));

  group('AppTypography.display', () {
    test('carries the Bengali fallback on every color mode, mono or proportional', () {
      for (final mode in AppColorMode.values) {
        expect(displayFor(mode).fontFamilyFallback,
            contains(AppTypography.bengaliFallback.single),
            reason: '$mode');
      }
    });

    test('isMono only flips for Retro', () {
      for (final mode in AppColorMode.values) {
        AppTypography.applyStyle(mode);
        expect(AppTypography.isMono, mode == AppColorMode.retro, reason: '$mode');
      }
    });
  });
}
