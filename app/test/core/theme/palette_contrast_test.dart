import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// Every filled primary button (Start Ride, Save, End Ride on most skins)
/// draws [AppTheme.primaryButtonForeground] on `palette.primary`. The default
/// Calming/Light skin shipped at 2.62:1 before this guard existed, so the
/// check covers every (color mode, brightness) pair rather than a sample.
void main() {
  for (final mode in AppColorMode.values) {
    for (final brightness in Brightness.values) {
      test('${mode.name}/${brightness.name} primary button text meets WCAG AA',
          () {
        final palette = AppColorPalette.forMode(mode, brightness);
        final fg = AppTheme.primaryButtonForeground(palette,
            isRetro: mode == AppColorMode.retro);
        final ratio = contrastRatio(palette.primary, fg);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${mode.name}/${brightness.name}: '
                '${ratio.toStringAsFixed(2)}:1 is below AA');
      });
    }
  }

  test('calmingLight keeps the old sage as the non-text highlight', () {
    expect(AppColorPalette.calmingLight.primary, const Color(0xFF537D5C));
    expect(AppColorPalette.calmingLight.primaryHighlight, const Color(0xFF84A98B));
  });
}
