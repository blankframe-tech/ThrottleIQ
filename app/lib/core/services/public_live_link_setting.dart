import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings → Privacy & Safety → "Password link (/r/@handle)".
///
/// A tapped Share still mints a private, unguessable `/live/{token}` link for
/// that one ride. The permanent `/r/{username}` link is the family / lost-phone
/// link: with it on, every ride shares to it, and after the ride (or if the
/// phone dies) it keeps the last known location. Anyone can learn a rider's
/// @handle, so it opens only with a password the rider sets (issues §90.D7).
///
/// The password is never stored or sent. The link lives at
/// `handleLinks/{linkKey(uid, password)}`, a doc id nobody can list or derive
/// without the password; the viewer recomputes the same hash. Only that key
/// is kept on the phone.
class PublicLiveLinkSetting {
  PublicLiveLinkSetting._();

  /// The key of the current link doc, or absent when the link is off.
  static const prefsKey = 'public_live_link_key';

  /// The old on/off flag from before the password. Ignored, so a rider who had
  /// the open link on starts with it off until they set a password.
  static const legacyPrefsKey = 'public_live_link_enabled';

  /// Firestore rules can't rate-limit guesses, so length is the only defence
  /// against someone who knows the handle trying passwords.
  static const minPasswordLength = 8;

  static const collection = 'handleLinks';

  /// Must match `linkKey` in public/live-viewer.html.
  static String linkKey(String uid, String password) =>
      sha256.convert(utf8.encode('throttleiq-r:$uid:$password')).toString();

  /// The current link key, or null when the link is off. Any read failure
  /// counts as off: the fail-safe direction for a location link.
  static Future<String?> currentKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefsKey);
    } catch (e) {
      debugPrint('PublicLiveLinkSetting read failed (treating as off): $e');
      return null;
    }
  }

  static Future<bool> isEnabled() async => await currentKey() != null;

  /// Turns the link on with [password], or changes the password. The doc
  /// under the old password is deleted, so the old password stops working.
  /// Takes effect from the next ride.
  static Future<void> enable({
    required String uid,
    required String password,
    FirebaseFirestore? firestore,
  }) async {
    if (password.length < minPasswordLength) {
      throw ArgumentError('password shorter than $minPasswordLength');
    }
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(prefsKey);
    final key = linkKey(uid, password);
    await prefs.setString(prefsKey, key);
    await prefs.remove(legacyPrefsKey);
    if (old != null && old != key) await _delete(old, firestore);
  }

  /// Turns the link off and deletes its doc right away, so the link stops
  /// resolving now instead of when the ride ends.
  static Future<void> disable({FirebaseFirestore? firestore}) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(prefsKey);
    await prefs.remove(prefsKey);
    await prefs.remove(legacyPrefsKey);
    if (old != null) await _delete(old, firestore);
  }

  static Future<void> _delete(String key, FirebaseFirestore? firestore) async {
    try {
      await (firestore ?? FirebaseFirestore.instance)
          .collection(collection)
          .doc(key)
          .delete()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      // Offline: the SDK keeps the delete queued and sends it later.
      debugPrint('PublicLiveLinkSetting: link delete failed: $e');
    }
  }
}
