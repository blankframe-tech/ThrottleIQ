import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ride/domain/entities/impact_event_types.dart';
import '../database/daos/impact_event_dao.dart';

/// Ride start → "Where's your phone?" The answer is remembered for the next
/// ride, so it's one tap only when it changes.
class PhonePlacementSetting {
  PhonePlacementSetting._();

  static const prefsKey = 'phone_placement';

  /// The last answer; [PhonePlacement.unknown] if never asked or unreadable.
  static Future<PhonePlacement> current() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PhonePlacement.fromWire(prefs.getString(prefsKey));
    } catch (e) {
      debugPrint('PhonePlacementSetting read failed: $e');
      return PhonePlacement.unknown;
    }
  }

  static Future<void> set(PhonePlacement placement) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, placement.wire);
  }
}

/// UI copy of [PhonePlacementSetting] for the ride-start chips.
class PhonePlacementNotifier extends StateNotifier<PhonePlacement> {
  PhonePlacementNotifier() : super(PhonePlacement.unknown) {
    PhonePlacementSetting.current().then((p) {
      if (mounted) state = p;
    });
  }

  Future<void> choose(PhonePlacement placement) async {
    state = placement;
    await PhonePlacementSetting.set(placement);
  }
}

final phonePlacementProvider =
    StateNotifierProvider<PhonePlacementNotifier, PhonePlacement>(
        (ref) => PhonePlacementNotifier());

/// Settings → Privacy & Safety → "Help improve crash detection". OFF by
/// default. When on, an impact the rider has answered about is also copied,
/// de-identified, to the central `crashEvents` collection (see
/// crashEventCloudPayload). The rider's own copy under
/// `users/{uid}/impactEvents` syncs either way, like their rides.
class CrashResearchConsent {
  CrashResearchConsent._();

  static const prefsKey = 'crash_research_consent';

  /// Bump when the consent text changes, so a central record says which
  /// wording the rider agreed to.
  static const int version = 1;

  /// Any read failure counts as OFF: the fail-safe direction for sharing.
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (e) {
      debugPrint('CrashResearchConsent read failed (treating as off): $e');
      return false;
    }
  }

  /// Persists the choice and re-queues the rider's answered impacts, so the
  /// next sync adds them to `crashEvents` (on) or removes them (off).
  static Future<void> setEnabled(bool value, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
    if (uid != null) {
      await ImpactEventDao().setConsentForUser(uid, value);
    }
  }
}
