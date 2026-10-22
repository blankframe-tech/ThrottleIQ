import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/services/app_modules.dart';
import '../../../../core/theme/app_theme_style.dart';
import '../../../../l10n/app_localizations.dart';

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
///   - Keep [TourTab] in the same order as [AppModules.tabs];
///     `test/features/auth/onboarding_manifest_test.dart` enforces it.
///   - A step's [OnboardingSlide.screenshot] is a real capture of its screen
///     (`assets/images/tour_*.jpg`). When that screen's layout changes,
///     recapture it and re-check every [SlidePointer.at].
const int kOnboardingManifestVersion = 5;

/// Every bottom-nav tab, in display order. Mirrors [AppModules.tabs]
/// (Maintenance is a tab only with ride tracking off), so the guardian can
/// check each step lives on a tab the rider actually has.
enum TourTab { social, places, record, rides, maintenance, garage }

extension TourTabX on TourTab {
  /// The shell route this tab opens.
  String get route => switch (this) {
        TourTab.social => '/home/social',
        TourTab.places => '/home/places',
        TourTab.record => '/home/record',
        TourTab.rides => '/home/stats',
        TourTab.maintenance => '/home/maintenance',
        TourTab.garage => '/home/profile',
      };
}

/// The tour's one accent: the app's primary, as long as it holds WCAG's 3:1
/// non-text contrast on the surface (accents only paint pins, rings and the
/// progress bar); on a palette where it doesn't, body ink.
Color tourAccent(AppColorPalette palette) =>
    _contrast(palette.primary, palette.surface) >= 3
        ? palette.primary
        : palette.textPrimary;

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
    this.at,
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

  /// Where the element sits on the step's screenshot, as fractions of its
  /// width and height. Null when the element isn't on that screen.
  final Offset? at;

  /// Beta-only control, shown with a BETA tag.
  final bool isBeta;
}

/// A single step of the feature tour.
class OnboardingSlide {
  const OnboardingSlide({
    required this.featureKey,
    required this.screenshot,
    required this.title,
    required this.subtitle,
    required this.tab,
    required this.location,
    required this.pointers,
    this.showMeRoute,
  });

  /// Stable identifier used by the guardian skill for diff comparisons.
  final String featureKey;

  /// Asset path of a real capture of the step's screen, status bar cropped.
  final String screenshot;

  /// Large title — one punchy phrase.
  final String title;

  /// One explanatory sentence.
  final String subtitle;

  /// The bottom-nav tab this feature lives under.
  final TourTab tab;

  /// Short breadcrumb of how to reach it ("Garage › Settings").
  final String location;

  /// Callouts for the elements of the screen.
  final List<SlidePointer> pointers;

  /// Optional route. When set, a "Show me" CTA opens the live screen while
  /// the tour waits (see `TourFloatingBanner`).
  final String? showMeRoute;
}

/// How many slides [onboardingSlides] returns with every module on. A plain
/// constant because `initState` needs it and cannot read localizations;
/// `onboarding_manifest_test.dart` keeps it honest.
const int kOnboardingSlideCount = 9;

/// The ordered feature tour, in the rider's language.
///
/// Steps are grouped by the tab they live on, so the tour walks the app
/// once: Record (and the ride it starts), Rides, everything under Garage
/// (Maintenance last: it is its own tab when ride tracking is off), then the
/// community tabs.
///
/// [showJamLabelling] adds the beta "I'm in a jam" callout to the cockpit
/// step; pass `canLabelJamsProvider` so only riders who actually see that
/// control on the live ride screen are told about it.
///
/// [modules] is the rider's Settings → Your ThrottleIQ choice: steps for a
/// module they turned off are left out and the rest skip callouts about it,
/// so the tour shows only the app they kept.
///
/// Guardian checks:
///   1. Every [OnboardingSlide.featureKey] must map to a real route or tab.
///   2. No real tab/major feature should be absent from this list.
///   3. The manifest version must be bumped whenever this list changes.
List<OnboardingSlide> onboardingSlides(
  AppLocalizations l10n, {
  bool showJamLabelling = false,
  AppModules modules = const AppModules(),
}) =>
    [
      if (modules.rideTracking) ...[
        // ── 1. RECORD TAB ─────────────────────────────────────────────────────
        OnboardingSlide(
          featureKey: 'ride_recording',
          screenshot: 'assets/images/tour_record.jpg',
          title: l10n.tourRecordTitle,
          subtitle: l10n.tourRecordSubtitle,
          tab: TourTab.record,
          location: l10n.navRecordLabel,
          showMeRoute: '/home/record',
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourRecordBikeTitle,
              description: l10n.tourRecordBikeBody,
              icon: Icons.two_wheeler,
              at: const Offset(0.85, 0.15),
            ),
            // Group rides are part of the social module.
            if (modules.social)
              SlidePointer(
                number: 2,
                title: l10n.tourRecordModeTitle,
                description: l10n.tourRecordModeBody,
                icon: Icons.group_outlined,
                at: const Offset(0.90, 0.46),
              ),
            SlidePointer(
              number: modules.social ? 3 : 2,
              title: l10n.tourRecordStartTitle,
              description: l10n.tourRecordStartBody,
              icon: Icons.touch_app_outlined,
              at: const Offset(0.68, 0.65),
            ),
          ],
        ),

        // ── 2. LIVE RIDE COCKPIT ──────────────────────────────────────────────
        // No "Show me": the cockpit only exists while a ride is recording.
        OnboardingSlide(
          featureKey: 'ride_cockpit',
          screenshot: 'assets/images/tour_cockpit.jpg',
          title: l10n.tourCockpitTitle,
          subtitle: l10n.tourCockpitSubtitle,
          tab: TourTab.record,
          location: l10n.tourCockpitLocation,
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourCockpitGaugesTitle,
              description: l10n.tourCockpitGaugesBody,
              icon: Icons.speed,
              at: const Offset(0.80, 0.62),
            ),
            SlidePointer(
              number: 2,
              title: l10n.tourCockpitShareTitle,
              description: l10n.tourCockpitShareBody,
              icon: Icons.share_location,
              at: const Offset(0.70, 0.10),
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

        // ── 3. RIDES TAB: ANALYTICS & BADGES ──────────────────────────────────
        OnboardingSlide(
          featureKey: 'rides_stats',
          screenshot: 'assets/images/tour_rides.jpg',
          title: l10n.tourRidesTitle,
          subtitle: l10n.tourRidesSubtitle,
          tab: TourTab.rides,
          location: l10n.navRidesLabel,
          showMeRoute: '/home/stats',
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourRidesScoreTitle,
              description: l10n.tourRidesScoreBody,
              icon: Icons.military_tech_outlined,
              at: const Offset(0.95, 0.15),
            ),
            SlidePointer(
              number: 2,
              title: l10n.tourRidesChartsTitle,
              description: l10n.tourRidesChartsBody,
              icon: Icons.show_chart,
              at: const Offset(0.93, 0.36),
            ),
            SlidePointer(
              number: 3,
              title: l10n.tourRidesBadgesTitle,
              description: l10n.tourRidesBadgesBody,
              icon: Icons.emoji_events_outlined,
              at: const Offset(0.70, 0.26),
            ),
          ],
        ),
      ],

      // ── 4. GARAGE TAB ─────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'garage',
        screenshot: 'assets/images/tour_garage.jpg',
        title: l10n.tourGarageTitle,
        subtitle: modules.rideTracking
            ? l10n.tourGarageSubtitle
            : l10n.tourGarageSubtitleNoTracking,
        tab: TourTab.garage,
        location: l10n.navGarageLabel,
        showMeRoute: '/home/profile',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourGarageActiveTitle,
            description: modules.rideTracking
                ? l10n.tourGarageActiveBody
                : l10n.tourGarageActiveBodyNoTracking,
            icon: Icons.star_outline_rounded,
            at: const Offset(0.72, 0.18),
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourGarageDetailTitle,
            description: modules.rideTracking
                ? l10n.tourGarageDetailBody
                : l10n.tourGarageDetailBodyNoTracking,
            icon: Icons.photo_camera_outlined,
            at: const Offset(0.92, 0.33),
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourGarageArchiveTitle,
            description: l10n.tourGarageArchiveBody,
            icon: Icons.archive_outlined,
          ),
        ],
      ),

      // ── 5. PROFILE ────────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'profile',
        screenshot: 'assets/images/tour_profile.jpg',
        title: l10n.tourProfileTitle,
        subtitle: modules.social
            ? l10n.tourProfileSubtitle
            : l10n.tourProfileSubtitleNoSocial,
        tab: TourTab.garage,
        location: l10n.tourProfileLocation,
        showMeRoute: '/profile',
        pointers: [
          // Follows and the follow QR are part of the social module.
          if (modules.social)
            SlidePointer(
              number: 1,
              title: l10n.tourProfileQrTitle,
              description: l10n.tourProfileQrBody,
              icon: Icons.qr_code_2,
              at: const Offset(0.50, 0.47),
            ),
          SlidePointer(
            number: modules.social ? 2 : 1,
            title: l10n.tourProfilePrivacyTitle,
            description: l10n.tourProfilePrivacyBody,
            icon: Icons.lock_outline,
            at: const Offset(0.88, 0.63),
          ),
          SlidePointer(
            number: modules.social ? 3 : 2,
            title: l10n.tourProfileSafeQrTitle,
            description: l10n.tourProfileSafeQrBody,
            icon: Icons.medical_information_outlined,
          ),
        ],
      ),

      // ── 6. AUTO TRACKING ──────────────────────────────────────────────────
      if (modules.rideTracking)
        OnboardingSlide(
          featureKey: 'auto_tracking',
          screenshot: 'assets/images/tour_auto.jpg',
          title: l10n.tourAutoTitle,
          subtitle: l10n.tourAutoSubtitle,
          tab: TourTab.garage,
          location: l10n.tourAutoLocation,
          showMeRoute: '/settings',
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourAutoDetectTitle,
              description: l10n.tourAutoDetectBody,
              icon: Icons.auto_awesome,
              at: const Offset(0.72, 0.385),
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

      // ── 7. MAINTENANCE ────────────────────────────────────────────────────
      OnboardingSlide(
        featureKey: 'maintenance',
        screenshot: 'assets/images/tour_maintenance.jpg',
        title: l10n.tourMaintenanceTitle,
        subtitle: l10n.tourMaintenanceSubtitle,
        // Its own tab when tracking is off; otherwise reached from Garage.
        tab: modules.rideTracking ? TourTab.garage : TourTab.maintenance,
        location: modules.rideTracking
            ? l10n.tourMaintenanceLocation
            : l10n.maintenance,
        showMeRoute: '/home/maintenance',
        pointers: [
          SlidePointer(
            number: 1,
            title: l10n.tourMaintenanceDueTitle,
            description: l10n.tourMaintenanceDueBody,
            icon: Icons.warning_amber_rounded,
            at: const Offset(0.93, 0.29),
          ),
          SlidePointer(
            number: 2,
            title: l10n.tourMaintenanceOdoTitle,
            description: l10n.tourMaintenanceOdoBody,
            icon: Icons.speed,
            at: const Offset(0.48, 0.08),
          ),
          SlidePointer(
            number: 3,
            title: l10n.tourMaintenanceLogTitle,
            description: l10n.tourMaintenanceLogBody,
            icon: Icons.check_circle_outline,
            at: const Offset(0.62, 0.78),
          ),
        ],
      ),

      // ── 8. PLACES TAB ─────────────────────────────────────────────────────
      if (modules.places)
        OnboardingSlide(
          featureKey: 'places',
          screenshot: 'assets/images/tour_places.jpg',
          title: l10n.tourPlacesTitle,
          subtitle: l10n.tourPlacesSubtitle,
          tab: TourTab.places,
          location: l10n.navPlacesLabel,
          showMeRoute: '/home/places',
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourPlacesMapTitle,
              description: l10n.tourPlacesMapBody,
              icon: Icons.map_outlined,
              at: const Offset(0.20, 0.52),
            ),
            SlidePointer(
              number: 2,
              title: l10n.tourPlacesRoutesTitle,
              description: l10n.tourPlacesRoutesBody,
              icon: Icons.route,
              at: const Offset(0.65, 0.09),
            ),
            SlidePointer(
              number: 3,
              title: l10n.tourPlacesAddTitle,
              description: l10n.tourPlacesAddBody,
              icon: Icons.add_location_alt_outlined,
              at: const Offset(0.82, 0.49),
            ),
          ],
        ),

      // ── 9. SOCIAL TAB ─────────────────────────────────────────────────────
      if (modules.social)
        OnboardingSlide(
          featureKey: 'social_forums',
          screenshot: 'assets/images/tour_social.jpg',
          title: l10n.tourSocialTitle,
          subtitle: l10n.tourSocialSubtitle,
          tab: TourTab.social,
          location: l10n.navSocialLabel,
          showMeRoute: '/home/social',
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourSocialFeedTitle,
              description: l10n.tourSocialFeedBody,
              icon: Icons.dynamic_feed_outlined,
              at: const Offset(0.30, 0.08),
            ),
            SlidePointer(
              number: 2,
              title: l10n.tourSocialForumsTitle,
              description: l10n.tourSocialForumsBody,
              icon: Icons.forum_outlined,
              at: const Offset(0.95, 0.08),
            ),
            SlidePointer(
              number: 3,
              title: l10n.tourSocialGroupTitle,
              description: l10n.tourSocialGroupBody,
              icon: Icons.headset_mic_outlined,
            ),
          ],
        )
      // Forums only: the same tab, renamed Forums, with nothing else on it.
      else if (modules.forums)
        OnboardingSlide(
          featureKey: 'social_forums',
          screenshot: 'assets/images/tour_social.jpg',
          title: l10n.tourSocialForumsTitle,
          subtitle: l10n.tourSocialForumsBody,
          tab: TourTab.social,
          location: l10n.forums,
          showMeRoute: '/home/social',
          pointers: [
            SlidePointer(
              number: 1,
              title: l10n.tourForumsFindTitle,
              description: l10n.tourForumsFindBody,
              icon: Icons.search,
              at: const Offset(0.66, 0.05),
            ),
            SlidePointer(
              number: 2,
              title: l10n.tourForumsAskTitle,
              description: l10n.tourForumsAskBody,
              icon: Icons.task_alt,
              at: const Offset(0.50, 0.42),
            ),
            SlidePointer(
              number: 3,
              title: l10n.tourForumsBikeTitle,
              description: l10n.tourForumsBikeBody,
              icon: Icons.two_wheeler,
              at: const Offset(0.43, 0.22),
            ),
          ],
        ),
    ];
