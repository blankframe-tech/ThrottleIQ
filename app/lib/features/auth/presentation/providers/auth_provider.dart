import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../profile/data/repositories/profile_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  // userChanges() (not authStateChanges()) is required here: it also fires after
  // reload()/updateProfile(), which authStateChanges() does not. Onboarding calls
  // updateDisplayName() then reload() on step 0; without a fresh emission here,
  // routerProvider's redirect closure keeps a stale `displayName == null` user and
  // permanently treats the account as "still onboarding", bouncing every later
  // navigation back to /auth/onboarding (resetting the screen's step) in a loop.
  return ref.watch(firebaseAuthProvider).userChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._auth) : super(const AsyncValue.data(null));

  final FirebaseAuth _auth;
  final ProfileRepository _profiles = ProfileRepository();

  /// Best-effort seeding of the public `users/{uid}` profile doc from the auth
  /// user. Never allowed to fail a sign-in — the profile can be re-seeded on
  /// the next launch — so failures (e.g. offline) are swallowed.
  Future<void> _seedProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _profiles.ensureProfile(user);
    } catch (_) {/* non-fatal */}
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _seedProfile();
    });
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _seedProfile();
    });
  }

  /// Google sign-in — also creates the account on first use.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user dismissed the picker
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      await _seedProfile();
    });
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    await _auth.currentUser?.reload();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _profiles.ensureProfile(_auth.currentUser!);
        await _profiles.updateProfile(uid: uid, displayName: name);
      } catch (_) {/* non-fatal — profile syncs on next launch */}
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(firebaseAuthProvider));
});
