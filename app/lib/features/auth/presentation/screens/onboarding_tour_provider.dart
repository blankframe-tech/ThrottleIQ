import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_manifest.dart';

/// SharedPreferences key for the onboarding tour completion flag.
///
/// Version-stamped: when [kOnboardingManifestVersion] bumps, the key
/// changes, so existing users who already completed the old tour will see
/// the new slides automatically on next launch.
String get _tourKey => 'onboarding_tour_v$kOnboardingManifestVersion';

/// True once the user has completed (or explicitly skipped) the feature-tour
/// slides. Reads from SharedPreferences synchronously via a FutureProvider.
///
/// The functional steps (name + bike) are gated separately by the router's
/// auth redirect (`displayName == null`). This flag only controls whether
/// the tour slides play after the functional steps complete.
final onboardingTourCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_tourKey) ?? false;
});

/// Marks the feature tour as complete for the current manifest version.
/// Call this before navigating away from the last slide, or when the user
/// taps "Skip tour".
Future<void> markOnboardingTourComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_tourKey, true);
}
