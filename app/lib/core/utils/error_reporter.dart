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

/// For a `catch` that swallows an error on purpose (best-effort work the app
/// carries on without, §83.14): records it as a non-fatal so it still shows on
/// the dashboard, tagged with [where]. A no-op in debug builds and tests, and
/// for Firestore being offline (expected, not a failure). Never throws.
void reportSilently(Object error, StackTrace? stack, {required String where}) {
  if (kDebugMode) return;
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return;
  }
  reportNonFatal(error, stack, reason: where);
}
