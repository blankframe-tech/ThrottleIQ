import 'package:firebase_auth/firebase_auth.dart';

import '../../l10n/app_localizations.dart';

/// Turns a Firestore read/stream error into something a rider can act on.
///
/// Without this, `FirebaseException(code: unavailable, message: "The
/// service is currently unavailable. This is most likely a transient
/// condition and may be corrected by retrying with a backoff...")` — the
/// SDK's own retry-policy explanation, meant for a developer reading logs —
/// was landing verbatim in the Social feed and Forums screens any time the
/// device was offline. See the issues log for the report this fixed.
String mapFirestoreError(Object error, AppLocalizations l10n) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' =>
        l10n.errOffline,
      'deadline-exceeded' =>
        l10n.errTimeout,
      'permission-denied' => l10n.errNoPermission,
      'not-found' => l10n.errNotFound,
      'resource-exhausted' =>
        l10n.errTooManyRequests,
      // A required Firestore composite index is missing or still building —
      // see DOCS/Handoff for agents and Todos/issues_open.md §81. Distinct
      // from the generic message so this failure mode is recognizable in
      // logs/screenshots instead of looking identical to every other error.
      'failed-precondition' =>
        l10n.errNotReady,
      _ => l10n.errLoadGeneric,
    };
  }

  final message = error.toString().toLowerCase();
  if (message.contains('socketexception') ||
      message.contains('network') ||
      message.contains('failed host lookup')) {
    return l10n.errOffline;
  }

  return l10n.errLoadGeneric;
}

String mapFirebaseAuthError(dynamic error, AppLocalizations l10n) {
  if (error == null) return l10n.errUnknown;

  final message = error.toString().toLowerCase();

  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'user-not-found' =>
        l10n.authUserNotFound,
      'wrong-password' => l10n.authWrongPassword,
      'invalid-email' => l10n.authInvalidEmail,
      'user-disabled' => l10n.authUserDisabled,
      'operation-not-allowed' => l10n.authOperationNotAllowed,
      'too-many-requests' => l10n.authTooManyRequests,
      'invalid-credential' => l10n.authInvalidCredential,
      'email-already-in-use' => l10n.authEmailInUse,
      'weak-password' => l10n.authWeakPassword,
      'network-request-failed' =>
        l10n.authNetworkFailed,
      'account-exists-with-different-credential' =>
        l10n.authAccountExistsDifferent,
      _ => l10n.authGeneric(error.message ?? 'Unknown error'),
    };
  }

  if (message.contains('network')) {
    return l10n.errNetworkFailed;
  }

  if (message.contains('permission')) {
    return l10n.errPermissionDenied;
  }

  // issues §33.17: this used to be `return error.toString();` — any
  // error that reached here (not a FirebaseAuthException, no recognizable
  // "network"/"permission" substring) had its raw exception text, which can
  // include internal type/stack details, put directly into a user-facing
  // SnackBar. A generic message is exactly as actionable to the rider and
  // leaks nothing internal.
  return l10n.errGeneric;
}

/// Turns a location/GPS error into something a rider can act on.
///
/// Covers permission-denied, service-disabled, and generic exceptions thrown
/// by [Geolocator] or the Places provider when the device GPS stack isn't
/// ready.
String mapLocationError(Object error, AppLocalizations l10n) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('service') && raw.contains('disabled') ||
      raw.contains('services are disabled') ||
      raw.contains('location services are off')) {
    return l10n.errLocationOff;
  }
  if (raw.contains('permission') ||
      raw.contains('denied') ||
      raw.contains('required to find')) {
    return l10n.errLocationPermission;
  }
  return l10n.errLocationGeneric;
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
