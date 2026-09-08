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
/// Current manifest version: 1
const int kOnboardingManifestVersion = 1;

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
  /// Tapping it marks the tour complete and navigates there immediately.
  final String? showMeRoute;
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
  ),
];
