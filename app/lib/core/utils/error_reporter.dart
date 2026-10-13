import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Reports a caught-and-handled error as a Crashlytics *non-fatal* (§90.B6).
///
/// Use this instead of a bare `debugPrint` in a `catch` that swallows an error
/// the app recovers from: `debugPrint` is invisible in release, so those
/// failures never reached anyone. Debug builds still print (Crashlytics
/// collection is off there — see `main.dart`).
///
/// Never throws: a reporting failure (Firebase not initialised, e.g. in unit
/// tests or before `Firebase.initializeApp`) is swallowed.
void reportNonFatal(Object error, StackTrace? stack, {String? reason}) {
  debugPrint('${reason ?? 'Non-fatal'}: $error');
  try {
    if (Firebase.apps.isEmpty) return;
    FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false)
        .catchError((Object _) {});
  } catch (_) {
    // Reporting must never take the app down with it.
  }
}
