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

/// Every filled primary button (Start Ride, Save, End Ride) draws
/// [AppTheme.primaryButtonForeground] on `palette.primary`. The default
/// Calming/Light theme shipped at 2.62:1 before this guard existed.
void main() {
  for (final brightness in Brightness.values) {
    test('${brightness.name} primary button text meets WCAG AA', () {
      final palette = AppColorPalette.forBrightness(brightness);
      final fg = AppTheme.primaryButtonForeground(palette);
      final ratio = contrastRatio(palette.primary, fg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason:
              '${brightness.name}: ${ratio.toStringAsFixed(2)}:1 is below AA');
    });
  }

  // WCAG 2.1 AA 4.5:1 for every token the app draws as small text, on every
  // surface it sits on. textTertiary is also the input hint on
  // surfaceVariant-filled fields; status/accent tokens are used as 11-14 px
  // labels on cards. `secondary` is left out: it is the brand accent, used for
  // fills and chart strokes; its one text use (the forum Gear tag) is an open
  // design call (light secondary is 2.69:1, issues_open.md 101.P2).
  for (final brightness in Brightness.values) {
    test('${brightness.name} text tokens meet WCAG AA on their surfaces', () {
      final p = AppColorPalette.forBrightness(brightness);
      final pairs = <String, (Color, Color)>{
        for (final (fgName, fg) in [
          ('textPrimary', p.textPrimary),
          ('textSecondary', p.textSecondary),
          ('textTertiary', p.textTertiary),
        ])
          for (final (bgName, bg) in [
            ('background', p.background),
            ('surface', p.surface),
            ('surfaceVariant', p.surfaceVariant),
          ])
            '$fgName on $bgName': (fg, bg),
        'primary (links) on background': (p.primary, p.background),
        'primary (links) on surface': (p.primary, p.surface),
        // Status pills (forum tags, place badges) draw the token as text on
        // an up-to-18% tint of itself.
        for (final (fgName, fg) in [
          ('success', p.success),
          ('warning', p.warning),
          ('danger', p.danger),
          ('attention', p.attention),
        ]) ...{
          for (final (bgName, bg) in [
            ('background', p.background),
            ('surface', p.surface),
            ('surfaceVariant', p.surfaceVariant),
          ])
            '$fgName on $bgName': (fg, bg),
          for (final (bgName, bg) in [
            ('background', p.background),
            ('surface', p.surface),
          ])
            '$fgName on its 18% tint over $bgName': (
              fg,
              Color.alphaBlend(fg.withValues(alpha: 0.18), bg)
            ),
        },
        'onInk on ink': (p.onInk, p.ink),
        'onInkMuted on ink': (p.onInkMuted, p.ink),
        'snackbar action on ink': (p.primaryHighlight, p.ink),
      };
      final failures = [
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries)
          if (contrastRatio(fg, bg) < 4.5)
            '$name ${contrastRatio(fg, bg).toStringAsFixed(2)}:1',
      ];
      expect(failures, isEmpty, reason: '${brightness.name} below AA');
    });
  }

  test('calmingLight keeps the old sage as the non-text highlight', () {
    expect(AppColorPalette.calmingLight.primary, const Color(0xFF517959));
    expect(
        AppColorPalette.calmingLight.primaryHighlight, const Color(0xFF84A98B));
  });
}
