import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/features/auth/presentation/screens/onboarding_manifest.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final locales = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'bn': AppLocalizationsBn(),
  };

  group('onboarding manifest', () {
    for (final entry in locales.entries) {
      test('${entry.key}: slide count matches kOnboardingSlideCount', () {
        expect(onboardingSlides(entry.value), hasLength(kOnboardingSlideCount));
        expect(onboardingSlides(entry.value, showJamLabelling: true),
            hasLength(kOnboardingSlideCount));
      });
    }

    test('feature keys are unique and cover every major feature', () {
      final keys = onboardingSlides(AppLocalizationsEn())
          .map((s) => s.featureKey)
          .toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(
        keys,
        containsAll(<String>[
          'ride_recording',
          'ride_cockpit',
          'auto_tracking',
          'rides_stats',
          'garage',
          'maintenance',
          'places',
          'social_forums',
          'profile',
        ]),
      );
    });

    test('TourTab mirrors the real bottom nav, in order', () {
      expect(TourTab.values, hasLength(shellTabs.length));
      expect(TourTab.values.map((t) => t.route).toList(), shellTabs);
      expect(TourTab.record.route, '/home/record');
      expect(TourTab.rides.route, '/home/stats');
      expect(TourTab.garage.route, '/home/profile');
    });

    test('every bottom-nav tab is spotlit by at least one step', () {
      final tabs =
          onboardingSlides(AppLocalizationsEn()).map((s) => s.tab).toSet();
      expect(tabs, TourTab.values.toSet());
    });

    test('every "Show me" route is a real route in app_router.dart', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      for (final slide in onboardingSlides(AppLocalizationsEn())) {
        final route = slide.showMeRoute;
        if (route == null) continue;
        expect(router.contains("path: '$route'"), isTrue,
            reason:
                '${slide.featureKey} points at $route, which no GoRoute serves');
      }
    });

    test('the cockpit step has no "Show me" (it only exists mid-ride)', () {
      final cockpit = onboardingSlides(AppLocalizationsEn())
          .firstWhere((s) => s.featureKey == 'ride_cockpit');
      expect(cockpit.showMeRoute, isNull);
    });

    test('callouts are numbered 1..n, and every step has at least three', () {
      for (final slide
          in onboardingSlides(AppLocalizationsEn(), showJamLabelling: true)) {
        expect(slide.pointers.length, greaterThanOrEqualTo(3),
            reason: slide.featureKey);
        expect(slide.pointers.map((p) => p.number).toList(),
            List.generate(slide.pointers.length, (i) => i + 1),
            reason: slide.featureKey);
      }
    });

    test('the jam-labelling callout is beta-only and gated by the flag', () {
      List<SlidePointer> cockpit(bool jam) =>
          onboardingSlides(AppLocalizationsEn(), showJamLabelling: jam)
              .firstWhere((s) => s.featureKey == 'ride_cockpit')
              .pointers;
      final en = AppLocalizationsEn();
      expect(cockpit(false).map((p) => p.title),
          isNot(contains(en.tourCockpitJamTitle)));
      final jam =
          cockpit(true).singleWhere((p) => p.title == en.tourCockpitJamTitle);
      expect(jam.isBeta, isTrue);
      // No other callout anywhere claims to be beta.
      final betas = onboardingSlides(en, showJamLabelling: true)
          .expand((s) => s.pointers)
          .where((p) => p.isBeta);
      expect(betas, hasLength(1));
    });

    test('accent tokens stay visible on the surface in every color mode', () {
      // Accents are only used for graphics (icons, rings, badges) — text sits
      // in textPrimary/textSecondary — so the bar is WCAG's 3:1 for non-text
      // UI, checked on every palette the rider can pick.
      final failures = <String>[];
      for (final mode in AppColorMode.values) {
        for (final brightness in Brightness.values) {
          final palette = AppColorPalette.forMode(mode, brightness);
          for (final accent in TourAccent.values) {
            final ratio = _contrast(accent.resolve(palette), palette.surface);
            if (ratio < 3) {
              failures.add('${mode.name}/${brightness.name}/${accent.name}: '
                  '${ratio.toStringAsFixed(2)}');
            }
          }
        }
      }
      expect(failures, isEmpty);
    });
  });
}
