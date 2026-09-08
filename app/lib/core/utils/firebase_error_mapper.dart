import 'package:firebase_auth/firebase_auth.dart';

/// Turns a Firestore read/stream error into something a rider can act on.
///
/// Without this, `FirebaseException(code: unavailable, message: "The
/// service is currently unavailable. This is most likely a transient
/// condition and may be corrected by retrying with a backoff...")` — the
/// SDK's own retry-policy explanation, meant for a developer reading logs —
/// was landing verbatim in the Social feed and Forums screens any time the
/// device was offline. See docs/Issues.md for the report this fixed.
String mapFirestoreError(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' =>
        "You're offline. Check your internet connection and try again.",
      'deadline-exceeded' =>
        "That's taking too long. Check your connection and try again.",
      'permission-denied' => "You don't have permission to view this.",
      'not-found' => 'That could not be found — it may have been removed.',
      'resource-exhausted' =>
        'Too many requests right now. Please try again in a moment.',
      _ => 'Something went wrong loading this. Please try again.',
    };
  }

  final message = error.toString().toLowerCase();
  if (message.contains('socketexception') ||
      message.contains('network') ||
      message.contains('failed host lookup')) {
    return "You're offline. Check your internet connection and try again.";
  }

  return 'Something went wrong loading this. Please try again.';
}

String mapFirebaseAuthError(dynamic error) {
  if (error == null) return 'An unknown error occurred';

  final message = error.toString().toLowerCase();

  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'user-not-found' => 'No account found with this email. Please sign up first.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-email' => 'Invalid email address.',
      'user-disabled' => 'This account has been disabled.',
      'operation-not-allowed' => 'Sign in with email is not enabled.',
      'too-many-requests' => 'Too many login attempts. Please try again later.',
      'invalid-credential' => 'Invalid email or password.',
      'email-already-in-use' => 'An account with this email already exists.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'network-request-failed' => 'Network error. Check your internet connection.',
      'account-exists-with-different-credential' =>
        'An account exists with this email but different sign-in method.',
      _ => 'Authentication error: ${error.message ?? "Unknown error"}',
    };
  }

  if (message.contains('network')) {
    return 'Network connection failed. Please check your internet.';
  }

  if (message.contains('permission')) {
    return 'Permission denied. Please check your account settings.';
  }

  // docs/Issues.md §33.17: this used to be `return error.toString();` — any
  // error that reached here (not a FirebaseAuthException, no recognizable
  // "network"/"permission" substring) had its raw exception text, which can
  // include internal type/stack details, put directly into a user-facing
  // SnackBar. A generic message is exactly as actionable to the rider and
  // leaks nothing internal.
  return 'Something went wrong. Please try again.';
}

/// Turns a location/GPS error into something a rider can act on.
///
/// Covers permission-denied, service-disabled, and generic exceptions thrown
/// by [Geolocator] or the Places provider when the device GPS stack isn't
/// ready.
String mapLocationError(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('service') && raw.contains('disabled') ||
      raw.contains('services are disabled') ||
      raw.contains('location services are off')) {
    return 'Location is turned off. Enable GPS in your device settings to use this feature.';
  }
  if (raw.contains('permission') ||
      raw.contains('denied') ||
      raw.contains('required to find')) {
    return 'Location permission is needed for this feature. Grant it in Settings → ThrottleIQ.';
  }
  return 'Could not get your location. Check that GPS is on and try again.';
}

/// Returns true when [error] is a "location services off" error, so the UI
/// can offer an "Open Location Settings" button instead of a generic retry.
bool isLocationServicesError(Object error) {
  final raw = error.toString().toLowerCase();
  return (raw.contains('service') && raw.contains('disabled')) ||
      raw.contains('services are disabled') ||
      raw.contains('location services are off');
}

/// Returns true when [error] is a location permission denial.
bool isLocationPermissionError(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('permission') || raw.contains('denied');
}
