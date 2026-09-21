import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// ONBOARDING MANIFEST — single source of truth for the ThrottleIQ feature-tour.
///
/// !! AGENT GUARDIAN NOTE !!
/// This file is audited by `.agents/skills/onboarding-guardian/SKILL.md` on
/// every pre-push to `main`. Rules:
///   - Add/modify/remove [OnboardingSlide] entries here whenever a **major**
///     feature is added, renamed, or removed from the app.
///   - Bump [kOnboardingManifestVersion] whenever the slide list changes so
///     existing users who have already completed the tour see the new slides.
///   - Keep [featureKey] values stable — they are used as map keys and for
///     the guardian's diff.
///
/// Current manifest version: 2
const int kOnboardingManifestVersion = 3;

/// A callout pointer on a visual UI mockup to "point and show, not just tell".
class SlidePointer {
  const SlidePointer({
    required this.number,
    required this.title,
    required this.description,
    this.icon,
  });

  /// 1-based index badge (1, 2, 3).
  final int number;

  /// Punchy callout title.
  final String title;

  /// Brief explanation pointing to this UI element.
  final String description;

  /// Optional icon representing the element.
  final IconData? icon;
}

/// A single feature-spotlight slide in the onboarding tour.
class OnboardingSlide {
  const OnboardingSlide({
    required this.featureKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.accentColor,
    this.showMeRoute,
    this.pointers = const [],
  });

  /// Stable identifier used by the guardian skill for diff comparisons.
  final String featureKey;

  /// Hero icon shown at 88dp in the slide centre.
  final IconData icon;

  /// Large title — one punchy sentence, ≤ 4 words.
  final String title;

  /// Subtitle — one explanatory sentence, ≤ 10 words.
  final String subtitle;

  /// 3–5 bullet strings describing what the user can do here.
  final List<String> bullets;

  /// Accent colour for the icon glow and bullet dots on this slide.
  final Color accentColor;

  /// Optional route path. When set, a "Show me →" secondary CTA appears.
  /// Tapping it opens the target feature while preserving the tour guide.
  final String? showMeRoute;

  /// Callout pointers that highlight exact UI elements on the screen mockup.
  final List<SlidePointer> pointers;
}

/// The ordered list of feature-spotlight slides, in the rider's language.
///
/// Guardian checks:
///   1. Every [featureKey] must map to a real route or nav tab.
///   2. No real tab/major feature should be absent from this list.
///   3. The manifest version must be bumped whenever this list changes.
/// How many slides [onboardingSlides] returns. A plain constant because
/// `initState` needs it and cannot read localizations; a test keeps it honest.
const int kOnboardingSlideCount = 7;

List<OnboardingSlide> onboardingSlides(AppLocalizations l10n) => [
  // ── 1. GARAGE ──────────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'garage',
    icon: Icons.two_wheeler,
    title: l10n.yourGarage,
    subtitle: l10n.everyBikeOwnTracked,
    bullets: [
      l10n.addUnlimitedBikesBrand,
      l10n.bikesPaintColorTints,
      l10n.tapAnyBikeView,
      l10n.switchActiveBikeBefore,
    ],
    accentColor: const Color(0xFF4CAF50),
    showMeRoute: '/home/profile',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.activeMotorcycle,
        description: l10n.tintsEntireAppTheme,
        icon: Icons.star_rounded,
      ),
      SlidePointer(
        number: 2,
        title: l10n.serviceCountdown,
        description: l10n.realTimeMaintenanceTracker,
        icon: Icons.speed,
      ),
      SlidePointer(
        number: 3,
        title: l10n.addSwitch,
        description: l10n.manageMultipleBikesSwap,
        icon: Icons.swap_horiz,
      ),
    ],
  ),

  // ── 2. RIDE RECORDING ──────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'ride_recording',
    icon: Icons.radio_button_checked,
    title: l10n.startRide,
    subtitle: l10n.holdButtonThrottleiqDoes,
    bullets: [
      l10n.holdStartRecordTab,
      l10n.gpsSensorFusionCaptures,
      l10n.continuesRecordingBackground,
      l10n.pausedRideSurvivesApp,
      l10n.shareLiveLocationWith,
    ],
    accentColor: const Color(0xFFFF5722),
    showMeRoute: '/home/record',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.cockpitTelemetry,
        description: l10n.liveGpsSpeedDistance,
        icon: Icons.speed,
      ),
      SlidePointer(
        number: 2,
        title: l10n.hold1sRecord,
        description: l10n.hold1sStartStop,
        icon: Icons.touch_app,
      ),
      SlidePointer(
        number: 3,
        title: l10n.liveShare,
        description: l10n.sendRevocableLinkSo,
        icon: Icons.share_location,
      ),
    ],
  ),

  // ── 3. AUTO TRACKING ───────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'auto_tracking',
    icon: Icons.sensors,
    title: l10n.autoTracking,
    subtitle: l10n.ridesThatDetectRecord,
    bullets: [
      l10n.enableOnceSettingsAuto,
      l10n.activityRecognitionStartsRecording,
      l10n.shortWalksSubwayTrips,
      l10n.eachAutoDetectedRide,
    ],
    accentColor: const Color(0xFF2196F3),
    showMeRoute: '/settings',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.smartDetection,
        description: l10n.detectsMotorcycleMovementVia,
        icon: Icons.auto_awesome,
      ),
      SlidePointer(
        number: 2,
        title: l10n.nonRideFilter,
        description: l10n.ignoresWalkingBusRides,
        icon: Icons.filter_alt,
      ),
      SlidePointer(
        number: 3,
        title: l10n.zeroInteraction,
        description: l10n.runsSilentlyBackgroundReview,
        icon: Icons.battery_charging_full,
      ),
    ],
  ),

  // ── 4. MAINTENANCE ─────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'maintenance',
    icon: Icons.build,
    title: l10n.maintenance,
    subtitle: l10n.neverForgetAnotherOil,
    bullets: [
      '13+ service types tracked by actual km ridden',
      l10n.alertsWhenYoureDue,
      l10n.logServiceResetCountdown,
      l10n.addCustomIntervalsAny,
    ],
    accentColor: const Color(0xFFFF9800),
    showMeRoute: '/home/maintenance',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.n13ServiceItems,
        description:
            l10n.trackEngineOilChain,
        icon: Icons.build_circle,
      ),
      SlidePointer(
        number: 2,
        title: l10n.dueBadges,
        description:
            l10n.colorCodedProgressBars,
        icon: Icons.warning_amber_rounded,
      ),
      SlidePointer(
        number: 3,
        title: l10n.logReset,
        description:
            l10n.recordMaintenanceNotesReset,
        icon: Icons.check_circle_outline,
      ),
    ],
  ),

  // ── 5. PLACES ──────────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'places',
    icon: Icons.place,
    title: l10n.riderPlaces,
    subtitle: l10n.everyGaragePumpViewpoint,
    bullets: [
      '395+ rider POIs pre-seeded across Dhaka metro',
      l10n.fuelStationsRepairShops,
      l10n.tapDirectionsOpensMaps,
      l10n.addRatePlacesHelp,
    ],
    accentColor: const Color(0xFF9C27B0),
    showMeRoute: '/home/places',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.n395RiderPois,
        description:
            l10n.verifiedFuelStationsWorkshops,
        icon: Icons.local_gas_station,
      ),
      SlidePointer(
        number: 2,
        title: l10n.navigateRecord,
        description:
            l10n.opensMapsAppCan,
        icon: Icons.navigation,
      ),
      SlidePointer(
        number: 3,
        title: l10n.riderReviews,
        description:
            l10n.rateOctanePurityMechanic,
        icon: Icons.rate_review,
      ),
    ],
  ),

  // ── 6. SOCIAL & FORUMS ─────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'social_forums',
    icon: Icons.people,
    title: l10n.rideTogether,
    subtitle: l10n.ridingCommunityAllOne,
    bullets: [
      l10n.shareRidesFeedHome,
      l10n.startGroupRideWith,
      l10n.pushTalkIntercomBluetooth,
      l10n.bikeModelForumsTalk,
      l10n.directMessageAnyRider,
    ],
    accentColor: const Color(0xFF00BCD4),
    showMeRoute: '/home/social',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.privacyZones,
        description:
            l10n.eachRidesStartEnd,
        icon: Icons.lock_outline,
      ),
      SlidePointer(
        number: 2,
        title: l10n.groupPinIntercom,
        description: l10n.liveMapTrackingBluetooth,
        icon: Icons.headset_mic,
      ),
      SlidePointer(
        number: 3,
        title: l10n.bikeModelForums,
        description:
            l10n.discussModsIssuesMeets,
        icon: Icons.forum,
      ),
    ],
  ),

  // ── 7. PROFILE ─────────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'profile',
    icon: Icons.person,
    title: l10n.yourProfile,
    subtitle: l10n.makeItYoursAdd,
    bullets: [
      l10n.publicProfileWithStats,
      l10n.handleLetsOtherRiders,
      l10n.controlWhoSeesProfile,
      l10n.safeqrOfflineEmergencyMedical,
    ],
    accentColor: const Color(0xFFE91E63),
    showMeRoute: '/home/profile',
    pointers: [
      SlidePointer(
        number: 1,
        title: l10n.riderStats,
        description: l10n.showcaseTotalKmSafety,
        icon: Icons.badge,
      ),
      SlidePointer(
        number: 2,
        title: l10n.safeqrCard,
        description:
            l10n.offlineMedicalCardEmergency,
        icon: Icons.qr_code,
      ),
      SlidePointer(
        number: 3,
        title: l10n.emergencyContactsSection,
        description: l10n.keepUp5Contacts,
        icon: Icons.contact_phone,
      ),
    ],
  ),
];
