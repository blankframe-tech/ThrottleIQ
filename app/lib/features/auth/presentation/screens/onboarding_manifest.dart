import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_style.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_shell.dart';

/// ONBOARDING MANIFEST — single source of truth for the ThrottleIQ feature tour.
///
/// !! AGENT GUARDIAN NOTE !!
/// This file is audited by `.agents/skills/onboarding-guardian/SKILL.md` on
/// every pre-push to `main`. Rules:
///   - Add/modify/remove [OnboardingSlide] entries here whenever a **major**
///     feature is added, renamed, moved, or removed from the app.
///   - Bump [kOnboardingManifestVersion] whenever the slide list changes so
///     existing users who have already completed the tour see the new slides.
///   - Keep [OnboardingSlide.featureKey] values stable — they are used as map
///     keys and for the guardian's diff.
///   - Keep [TourTab] in the same order as `shellTabs` in `app_shell.dart`;
///     `test/features/auth/onboarding_manifest_test.dart` enforces it.
const int kOnboardingManifestVersion = 4;

/// The bottom-nav tabs, in display order. Mirrors `shellTabs` in
/// `app_shell.dart` (index for index) so a step can spotlight "where" a
/// feature lives on the real navigation bar.
enum TourTab { social, places, record, rides, garage }

extension TourTabX on TourTab {
  /// The shell route this tab opens.
  String get route => shellTabs[index];

  /// Same icons as the real `BottomNavigationBar` in `app_shell.dart`.
  IconData get icon => switch (this) {
        TourTab.social => Icons.people_outline,
        TourTab.places => Icons.place_outlined,
        TourTab.record => Icons.radio_button_checked_outlined,
        TourTab.rides => Icons.insights_outlined,
        TourTab.garage => Icons.two_wheeler_outlined,
      };

  IconData get activeIcon => switch (this) {
        TourTab.social => Icons.people,
        TourTab.places => Icons.place,
        TourTab.record => Icons.radio_button_checked,
        TourTab.rides => Icons.insights,
        TourTab.garage => Icons.two_wheeler,
      };

  /// Same labels as the real nav bar.
  String label(AppLocalizations l10n) => switch (this) {
        TourTab.social => l10n.navSocialLabel,
        TourTab.places => l10n.navPlacesLabel,
        TourTab.record => l10n.navRecordLabel,
        TourTab.rides => l10n.navRidesLabel,
        TourTab.garage => l10n.navGarageLabel,
      };
}

/// A slide's accent, as a *token* rather than a literal color, so it follows
/// whichever color mode and brightness the rider picked.
enum TourAccent { primary, secondary, attention, success, warning }

extension TourAccentX on TourAccent {
  Color _raw(AppColorPalette palette) => switch (this) {
        TourAccent.primary => palette.primary,
        TourAccent.secondary => palette.secondary,
        TourAccent.attention => palette.attention,
        TourAccent.success => palette.success,
        TourAccent.warning => palette.warning,
      };

  /// The accent for [palette]. Accents only paint graphics (icons, rings,
  /// badges), so each must hold WCAG's 3:1 non-text contrast on the surface;
  /// a token that doesn't on some palette (pale secondaries/warnings on the
  /// light skins) falls back to primary, then to body ink.
  Color resolve(AppColorPalette palette) {
    for (final c in [_raw(palette), palette.primary]) {
      if (_contrast(c, palette.surface) >= 3) return c;
    }
    return palette.textPrimary;
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A numbered callout explaining one element of the step's screen.
class SlidePointer {
  const SlidePointer({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.isBeta = false,
  });

  /// 1-based index badge (1, 2, 3…).
  final int number;

  /// Punchy callout title.
  final String title;

  /// Brief explanation of the element.
  final String description;

  /// Icon representing the element (matches the icon used in the real UI).
  final IconData icon;

  /// Beta-only control, shown with a BETA tag.
  final bool isBeta;
}

/// A single step of the feature tour.
class OnboardingSlide {
  const OnboardingSlide({
    required this.featureKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tab,
    required this.location,
    required this.pointers,
    this.showMeRoute,
  });

  /// Stable identifier used by the guardian skill for diff comparisons.
  final String featureKey;

  /// Hero icon shown in the step's spotlight.
  final IconData icon;

  /// Large title — one punchy phrase.
  final String title;

  /// One explanatory sentence.
  final String subtitle;

  /// Accent token for the spotlight and callout badges.
  final TourAccent accent;

  /// The bottom-nav tab this feature lives under — spotlighted in the preview.
  final TourTab tab;

  /// Short breadcrumb of how to reach it ("Garage › Settings").
  final String location;

  /// Callouts for the elements of the screen.
  final List<SlidePointer> pointers;

  /// Optional route. When set, a "Show me" CTA opens the live screen while
  /// the tour waits (see `TourFloatingBanner`).
  final String? showMeRoute;
}

/// How many slides [onboardingSlides] returns. A plain constant because
/// `initState` needs it and cannot read localizations;
/// `onboarding_manifest_test.dart` keeps it honest.
const int kOnboardingSlideCount = 9;

/// The ordered feature tour, in the rider's language.
///
/// [showJamLabelling] adds the beta "I'm in a jam" callout to the cockpit
/// step; pass `canLabelJamsProvider` so only riders who actually see that
/// control on the live ride screen are told about it.
///
/// Guardian checks:
///   1. Every [OnboardingSlide.featureKey] must map to a real route or tab.
///   2. No real tab/major feature should be absent from this list.
///   3. The manifest version must be bumped whenever this list changes.
List<OnboardingSlide> onboardingSlides(
  AppLocalizations l10n, {
  bool showJamLabelling = false,
}) =>
    [
      // ── 1. RECORD TAB ─────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'ride_recording',
        icon: Icons.radio_button_checked,
        title: l10n.tourRecordTitle,
        subtitle: l10n.tourRecordSubtitle,
        accent: TourAccent.primary,
        tab: TourTab.record,
        location: l10n.navRecordLabel,
        showMeRoute: '/home/record',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourRecordBikeTitle,
            description: l10n.tourRecordBikeBody,
            icon: Icons.two_wheeler,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourRecordModeTitle,
            description: l10n.tourRecordModeBody,
            icon: Icons.group_outlined,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourRecordStartTitle,
            description: l10n.tourRecordStartBody,
            icon: Icons.touch_app_outlined,
          ),
        ],
      ),

      // ── 2. LIVE RIDE COCKPIT ──────────────────────────────────────────────
      // No "Show me": the cockpit only exists while a ride is recording.
      OnboardingSlide(
        featureKey: 'ride_cockpit',
        icon: Icons.speed,
        title: l10n.tourCockpitTitle,
        subtitle: l10n.tourCockpitSubtitle,
        accent: TourAccent.secondary,
        tab: TourTab.record,
        location: l10n.tourCockpitLocation,
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourCockpitGaugesTitle,
            description: l10n.tourCockpitGaugesBody,
            icon: Icons.speed,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourCockpitShareTitle,
            description: l10n.tourCockpitShareBody,
            icon: Icons.share_location,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourCockpitSafetyTitle,
            description: l10n.tourCockpitSafetyBody,
            icon: Icons.health_and_safety_outlined,
          ),
          if (showJamLabelling)
            SlidePointer(
              number: 4,
              title: l10n.tourCockpitJamTitle,
              description: l10n.tourCockpitJamBody,
              icon: Icons.traffic_outlined,
              isBeta: true,
            ),
        ],
      ),

      // ── 3. AUTO TRACKING ──────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'auto_tracking',
        icon: Icons.sensors,
        title: l10n.tourAutoTitle,
        subtitle: l10n.tourAutoSubtitle,
        accent: TourAccent.success,
        tab: TourTab.garage,
        location: l10n.tourAutoLocation,
        showMeRoute: '/settings',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourAutoDetectTitle,
            description: l10n.tourAutoDetectBody,
            icon: Icons.auto_awesome,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourAutoFilterTitle,
            description: l10n.tourAutoFilterBody,
            icon: Icons.filter_alt_outlined,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourAutoHistoryTitle,
            description: l10n.tourAutoHistoryBody,
            icon: Icons.history,
          ),
        ],
      ),

      // ── 4. RIDES TAB: ANALYTICS & BADGES ──────────────────────────────────
      OnboardingSlide(
        featureKey: 'rides_stats',
        icon: Icons.insights,
        title: l10n.tourRidesTitle,
        subtitle: l10n.tourRidesSubtitle,
        accent: TourAccent.attention,
        tab: TourTab.rides,
        location: l10n.navRidesLabel,
        showMeRoute: '/home/stats',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourRidesScoreTitle,
            description: l10n.tourRidesScoreBody,
            icon: Icons.military_tech_outlined,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourRidesChartsTitle,
            description: l10n.tourRidesChartsBody,
            icon: Icons.show_chart,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourRidesBadgesTitle,
            description: l10n.tourRidesBadgesBody,
            icon: Icons.emoji_events_outlined,
          ),
        ],
      ),

      // ── 5. GARAGE TAB ─────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'garage',
        icon: Icons.two_wheeler,
        title: l10n.tourGarageTitle,
        subtitle: l10n.tourGarageSubtitle,
        accent: TourAccent.primary,
        tab: TourTab.garage,
        location: l10n.navGarageLabel,
        showMeRoute: '/home/profile',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourGarageActiveTitle,
            description: l10n.tourGarageActiveBody,
            icon: Icons.star_outline_rounded,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourGarageDetailTitle,
            description: l10n.tourGarageDetailBody,
            icon: Icons.photo_camera_outlined,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourGarageArchiveTitle,
            description: l10n.tourGarageArchiveBody,
            icon: Icons.archive_outlined,
          ),
        ],
      ),

      // ── 6. MAINTENANCE ────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'maintenance',
        icon: Icons.build_outlined,
        title: l10n.tourMaintenanceTitle,
        subtitle: l10n.tourMaintenanceSubtitle,
        accent: TourAccent.warning,
        tab: TourTab.garage,
        location: l10n.tourMaintenanceLocation,
        showMeRoute: '/home/maintenance',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourMaintenanceDueTitle,
            description: l10n.tourMaintenanceDueBody,
            icon: Icons.warning_amber_rounded,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourMaintenanceOdoTitle,
            description: l10n.tourMaintenanceOdoBody,
            icon: Icons.speed,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourMaintenanceLogTitle,
            description: l10n.tourMaintenanceLogBody,
            icon: Icons.check_circle_outline,
          ),
        ],
      ),

      // ── 7. PLACES TAB ─────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'places',
        icon: Icons.place,
        title: l10n.tourPlacesTitle,
        subtitle: l10n.tourPlacesSubtitle,
        accent: TourAccent.success,
        tab: TourTab.places,
        location: l10n.navPlacesLabel,
        showMeRoute: '/home/places',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourPlacesMapTitle,
            description: l10n.tourPlacesMapBody,
            icon: Icons.map_outlined,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourPlacesRoutesTitle,
            description: l10n.tourPlacesRoutesBody,
            icon: Icons.route,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourPlacesAddTitle,
            description: l10n.tourPlacesAddBody,
            icon: Icons.add_location_alt_outlined,
          ),
        ],
      ),

      // ── 8. SOCIAL TAB ─────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'social_forums',
        icon: Icons.people,
        title: l10n.tourSocialTitle,
        subtitle: l10n.tourSocialSubtitle,
        accent: TourAccent.secondary,
        tab: TourTab.social,
        location: l10n.navSocialLabel,
        showMeRoute: '/home/social',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourSocialFeedTitle,
            description: l10n.tourSocialFeedBody,
            icon: Icons.dynamic_feed_outlined,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourSocialForumsTitle,
            description: l10n.tourSocialForumsBody,
            icon: Icons.forum_outlined,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourSocialGroupTitle,
            description: l10n.tourSocialGroupBody,
            icon: Icons.headset_mic_outlined,
          ),
        ],
      ),

      // ── 9. PROFILE ────────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'profile',
        icon: Icons.person,
        title: l10n.tourProfileTitle,
        subtitle: l10n.tourProfileSubtitle,
        accent: TourAccent.attention,
        tab: TourTab.garage,
        location: l10n.tourProfileLocation,
        showMeRoute: '/profile',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourProfileQrTitle,
            description: l10n.tourProfileQrBody,
            icon: Icons.qr_code_2,
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourProfilePrivacyTitle,
            description: l10n.tourProfilePrivacyBody,
            icon: Icons.lock_outline,
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourProfileSafeQrTitle,
            description: l10n.tourProfileSafeQrBody,
            icon: Icons.medical_information_outlined,
          ),
        ],
      ),
    ];
