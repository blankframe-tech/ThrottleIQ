import 'package:firebase_auth/firebase_auth.dart';

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

  return error.toString();
}
