import 'package:flutter/material.dart';

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
const int kOnboardingManifestVersion = 2;

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

/// The ordered list of feature-spotlight slides.
///
/// Guardian checks:
///   1. Every [featureKey] must map to a real route or nav tab.
///   2. No real tab/major feature should be absent from this list.
///   3. The manifest version must be bumped whenever this list changes.
const List<OnboardingSlide> kOnboardingSlides = [
  // ── 1. GARAGE ──────────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'garage',
    icon: Icons.two_wheeler,
    title: 'Your Garage',
    subtitle: 'Every bike you own, tracked in one place.',
    bullets: [
      'Add unlimited bikes — brand, model, year, CC',
      'Your bike\'s paint color tints the whole app',
      'Tap any bike to view full history & details',
      'Switch active bike before each ride',
    ],
    accentColor: Color(0xFF4CAF50),
    showMeRoute: '/home/profile',
    pointers: [
      SlidePointer(
        number: 1,
        title: 'Active Motorcycle',
        description: 'Tints the entire app theme and binds to your trip logs.',
        icon: Icons.star_rounded,
      ),
      SlidePointer(
        number: 2,
        title: 'Service Countdown',
        description: 'Real-time maintenance tracker based on actual km ridden.',
        icon: Icons.speed,
      ),
      SlidePointer(
        number: 3,
        title: 'Add & Switch',
        description: 'Manage multiple bikes and swap your active ride anytime.',
        icon: Icons.swap_horiz,
      ),
    ],
  ),

  // ── 2. RIDE RECORDING ──────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'ride_recording',
    icon: Icons.radio_button_checked,
    title: 'Start a Ride',
    subtitle: 'Hold the button. ThrottleIQ does the rest.',
    bullets: [
      'Hold-to-start on the Record tab to begin',
      'GPS + sensor fusion captures every moment',
      'Continues recording in the background',
      'Instant crash detection with 60s cancel window',
      'Share your live location with family in real time',
    ],
    accentColor: Color(0xFFFF5722),
    showMeRoute: '/home/record',
    pointers: [
      SlidePointer(
        number: 1,
        title: 'Cockpit Telemetry',
        description: 'Live Doppler speed, lean angle arc, and GPS telemetry.',
        icon: Icons.speed,
      ),
      SlidePointer(
        number: 2,
        title: 'Hold 1s to Record',
        description: 'Hold 1s to start or stop; prevents accidental touches.',
        icon: Icons.touch_app,
      ),
      SlidePointer(
        number: 3,
        title: 'Crash Shield',
        description: 'Impact & tumble detection with 60s emergency cancellation.',
        icon: Icons.security,
      ),
    ],
  ),

  // ── 3. AUTO TRACKING ───────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'auto_tracking',
    icon: Icons.sensors,
    title: 'Auto Tracking',
    subtitle: 'Rides that detect and record themselves.',
    bullets: [
      'Enable once in Settings → Auto-Tracking',
      'Activity recognition starts recording when you ride',
      'Short walks and subway trips are filtered out',
      'Each auto-detected ride appears ready to review',
    ],
    accentColor: Color(0xFF2196F3),
    showMeRoute: '/settings',
    pointers: [
      SlidePointer(
        number: 1,
        title: 'Smart Detection',
        description: 'Detects motorcycle movement via IMU sensors & speed.',
        icon: Icons.auto_awesome,
      ),
      SlidePointer(
        number: 2,
        title: 'Non-Ride Filter',
        description: 'Ignores walking, bus rides, and minor phone jostling.',
        icon: Icons.filter_alt,
      ),
      SlidePointer(
        number: 3,
        title: 'Zero Interaction',
        description: 'Runs silently in background; review rides when done.',
        icon: Icons.battery_charging_full,
      ),
    ],
  ),

  // ── 4. MAINTENANCE ─────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'maintenance',
    icon: Icons.build,
    title: 'Maintenance',
    subtitle: 'Never forget another oil change.',
    bullets: [
      '13+ service types tracked by actual km ridden',
      'Alerts when you\'re due for oil, filter, chain lube…',
      'Log a service to reset the countdown',
      'Add custom intervals for any part you care about',
    ],
    accentColor: Color(0xFFFF9800),
    showMeRoute: '/home/maintenance',
    pointers: [
      SlidePointer(
        number: 1,
        title: '13+ Service Items',
        description: 'Track engine oil, chain lube, brake fluid, coolant, and more.',
        icon: Icons.build_circle,
      ),
      SlidePointer(
        number: 2,
        title: 'Due Badges',
        description: 'Color-coded progress bars alert you before intervals expire.',
        icon: Icons.warning_amber_rounded,
      ),
      SlidePointer(
        number: 3,
        title: 'Log & Reset',
        description: 'Record maintenance notes and reset the interval odometer.',
        icon: Icons.check_circle_outline,
      ),
    ],
  ),

  // ── 5. PLACES ──────────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'places',
    icon: Icons.place,
    title: 'Rider Places',
    subtitle: 'Every garage, pump, and viewpoint near you.',
    bullets: [
      '395+ rider POIs pre-seeded across Dhaka metro',
      'Fuel stations, repair shops, spare parts & cafes',
      'Tap Directions → opens Maps and starts recording',
      'Add and rate places to help the community',
    ],
    accentColor: Color(0xFF9C27B0),
    showMeRoute: '/home/places',
    pointers: [
      SlidePointer(
        number: 1,
        title: '395+ Rider POIs',
        description: 'Verified fuel stations, workshops, parts, and rider cafes.',
        icon: Icons.local_gas_station,
      ),
      SlidePointer(
        number: 2,
        title: 'Navigate & Record',
        description: 'Opens Google Maps directions and begins ride telemetry.',
        icon: Icons.navigation,
      ),
      SlidePointer(
        number: 3,
        title: 'Rider Reviews',
        description: 'Rate octane purity, mechanic honesty, and parking security.',
        icon: Icons.rate_review,
      ),
    ],
  ),

  // ── 6. SOCIAL & FORUMS ─────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'social_forums',
    icon: Icons.people,
    title: 'Ride Together',
    subtitle: 'Your riding community, all in one place.',
    bullets: [
      'Share rides to the feed — home location is hidden',
      'Start a group ride with a 6-character join code',
      'Push-to-talk intercom for your Bluetooth helmet',
      'Bike-model forums — talk to FZ-S, Pulsar & CBR riders',
      'Direct message any rider on the platform',
    ],
    accentColor: Color(0xFF00BCD4),
    showMeRoute: '/home/social',
    pointers: [
      SlidePointer(
        number: 1,
        title: 'Privacy Zones',
        description: '200m buffer automatically clipped at home & work endpoints.',
        icon: Icons.lock_outline,
      ),
      SlidePointer(
        number: 2,
        title: 'Group PIN & Intercom',
        description: 'Live map tracking and Bluetooth helmet PTT intercom.',
        icon: Icons.headset_mic,
      ),
      SlidePointer(
        number: 3,
        title: 'Bike Model Forums',
        description: 'Discuss mods, issues, and meets with owners of your bike.',
        icon: Icons.forum,
      ),
    ],
  ),

  // ── 7. PROFILE ─────────────────────────────────────────────────────────────
  OnboardingSlide(
    featureKey: 'profile',
    icon: Icons.person,
    title: 'Your Profile',
    subtitle: 'Make it yours — add a bio to stand out.',
    bullets: [
      'Public profile with your stats & shared rides',
      'Your @handle lets other riders find and follow you',
      'Control who sees your profile and your bikes',
      'SafeQR: an offline emergency medical card',
    ],
    accentColor: Color(0xFFE91E63),
    showMeRoute: '/home/profile',
    pointers: [
      SlidePointer(
        number: 1,
        title: 'Rider Stats',
        description: 'Showcase total km, safety score, and peak achievements.',
        icon: Icons.badge,
      ),
      SlidePointer(
        number: 2,
        title: 'SafeQR Card',
        description: 'Offline medical card for emergency responders on the road.',
        icon: Icons.qr_code,
      ),
      SlidePointer(
        number: 3,
        title: 'SOS Contacts',
        description: 'Automated SMS / alert notification to trusted contacts on crash.',
        icon: Icons.contact_phone,
      ),
    ],
  ),
];
