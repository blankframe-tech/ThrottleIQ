import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings → Privacy & Safety → "Public link (/r/@handle)" (issues §90.D7).
///
/// A live share always mints a private, unguessable `/live/{token}` link. The
/// permanent `/r/{username}` link is different: anyone who knows the rider's
/// @handle can open it, without signing in, whenever they are sharing. That
/// used to be published silently on every share. It is now written only when
/// the rider turns this on — OFF by default.
class PublicLiveLinkSetting {
  PublicLiveLinkSetting._();

  static const prefsKey = 'public_live_link_enabled';

  /// Whether the rider has opted in. Any read failure counts as OFF: the
  /// fail-safe direction for a link strangers can open.
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (e) {
      debugPrint('PublicLiveLinkSetting read failed (treating as off): $e');
      return false;
    }
  }

  /// Persists the choice. Turning it OFF also clears `livePointers/{uid}`
  /// right away, so a link that is live at that moment stops resolving
  /// instead of lasting until the ride ends. Turning it ON takes effect from
  /// the next live share.
  static Future<void> setEnabled(bool value, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
    if (!value && uid != null) {
      try {
        await FirebaseFirestore.instance.collection('livePointers').doc(uid).set({
          'uid': uid,
          'token': null,
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
      } catch (e) {
        // Offline: the SDK keeps the write queued and sends it later.
        // The pointer is also cleared at ride end by the outbox teardown.
        debugPrint('PublicLiveLinkSetting: pointer clear failed: $e');
      }
    }
  }
}
