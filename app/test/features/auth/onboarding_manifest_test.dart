import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/features/auth/presentation/screens/onboarding_manifest.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

/// Every Settings → Your ThrottleIQ combination a rider can pick.
final _moduleMixes = [
  for (final community in CommunityMode.values)
    for (final places in [true, false])
      for (final rideTracking in [true, false])
        AppModules(
            community: community, places: places, rideTracking: rideTracking),
];

String _describe(AppModules m) =>
    'community ${m.community.name}, places ${m.places}, tracking ${m.rideTracking}';

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

    test('TourTab mirrors the real bottom nav, in order, for every module mix',
        () {
      final routes = TourTab.values.map((t) => t.route);
      expect(routes.where(shellTabs.contains).toList(), shellTabs);
      for (final m in _moduleMixes) {
        expect(routes.where(m.tabs.contains).toList(), m.tabs,
            reason: _describe(m));
      }
      expect(TourTab.record.route, '/home/record');
      expect(TourTab.rides.route, '/home/stats');
      expect(TourTab.garage.route, '/home/profile');
    });

    test('steps spotlight exactly the tabs the rider has', () {
      for (final m in _moduleMixes) {
        final spotlit = onboardingSlides(AppLocalizationsEn(), modules: m)
            .map((s) => s.tab.route)
            .toSet();
        expect(spotlit, m.tabs.toSet(), reason: _describe(m));
      }
    });

    test('every "Show me" route is a real route the rider can open', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      for (final m in _moduleMixes) {
        for (final slide
            in onboardingSlides(AppLocalizationsEn(), modules: m)) {
          final route = slide.showMeRoute;
          if (route == null) continue;
          expect(router.contains("path: '$route'"), isTrue,
              reason:
                  '${slide.featureKey} points at $route, which no GoRoute serves');
          expect(m.redirectFor(route), isNull,
              reason: '${slide.featureKey} with ${_describe(m)}');
        }
      }
    });

    test('steps follow Settings → Your ThrottleIQ', () {
      final en = AppLocalizationsEn();
      List<String> keys(AppModules m) =>
          onboardingSlides(en, modules: m).map((s) => s.featureKey).toList();
      expect(keys(const AppModules(rideTracking: false)),
          ['garage', 'maintenance', 'places', 'social_forums', 'profile']);
      expect(keys(const AppModules(places: false)), isNot(contains('places')));
      expect(
          keys(const AppModules(
              community: CommunityMode.off,
              places: false,
              rideTracking: false)),
          ['garage', 'maintenance', 'profile']);

      // Forums only keeps the tab, renamed, and tells only about the forums.
      final forums = onboardingSlides(en,
              modules: const AppModules(community: CommunityMode.forumsOnly))
          .singleWhere((s) => s.featureKey == 'social_forums');
      expect(forums.title, en.tourSocialForumsTitle);
      expect(forums.pointers.map((p) => p.title), [
        en.tourForumsFindTitle,
        en.tourForumsAskTitle,
        en.tourForumsBikeTitle,
      ]);
    });

    test('no step or callout describes a module the rider turned off', () {
      final en = AppLocalizationsEn();
      final socialCopy = {
        en.tourRecordModeTitle,
        en.tourProfileQrTitle,
        en.tourProfileSubtitle,
        en.tourSocialFeedTitle,
        en.tourSocialGroupTitle,
      };
      final rideCopy = {
        en.tourGarageSubtitle,
        en.tourGarageActiveBody,
        en.tourGarageDetailBody,
      };
      for (final m in _moduleMixes) {
        final copy = {
          for (final s in onboardingSlides(en, modules: m)) ...[
            s.subtitle,
            for (final p in s.pointers) ...[p.title, p.description],
          ],
        };
        if (!m.social) {
          expect(copy.intersection(socialCopy), isEmpty, reason: _describe(m));
        }
        if (!m.rideTracking) {
          expect(copy.intersection(rideCopy), isEmpty, reason: _describe(m));
        }
      }
    });

    test('the cockpit step has no "Show me" (it only exists mid-ride)', () {
      final cockpit = onboardingSlides(AppLocalizationsEn())
          .firstWhere((s) => s.featureKey == 'ride_cockpit');
      expect(cockpit.showMeRoute, isNull);
    });

    test(
        'callouts are numbered 1..n; every step has three, or two once a '
        'module is off', () {
      for (final m in _moduleMixes) {
        final allOn = m.social && m.places && m.rideTracking;
        for (final slide in onboardingSlides(AppLocalizationsEn(),
            showJamLabelling: true, modules: m)) {
          final reason = '${slide.featureKey} with ${_describe(m)}';
          expect(slide.pointers.length, greaterThanOrEqualTo(allOn ? 3 : 2),
              reason: reason);
          expect(slide.pointers.map((p) => p.number).toList(),
              List.generate(slide.pointers.length, (i) => i + 1),
              reason: reason);
        }
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

    test('accent tokens stay visible on the surface in both themes', () {
      // Accents are only used for graphics (icons, rings, badges) — text sits
      // in textPrimary/textSecondary — so the bar is WCAG's 3:1 for non-text
      // UI, checked on both palettes.
      final failures = <String>[];
      for (final brightness in Brightness.values) {
        final palette = AppColorPalette.forBrightness(brightness);
        for (final accent in TourAccent.values) {
          final ratio = _contrast(accent.resolve(palette), palette.surface);
          if (ratio < 3) {
            failures.add('${brightness.name}/${accent.name}: '
                '${ratio.toStringAsFixed(2)}');
          }
        }
      }
      expect(failures, isEmpty);
    });
  });
}
