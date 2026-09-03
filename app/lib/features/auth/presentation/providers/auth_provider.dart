import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/database/database_helper.dart';
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
      await _ensureUsername(user);
    } catch (_) {/* non-fatal */}
  }

  /// Every rider ends up with an @handle even if they never touch the
  /// onboarding/edit-profile username field: default to their email's local
  /// part, falling back to a numeric suffix if that's taken. Runs on every
  /// login (cheap — one doc read when a username already exists) so it also
  /// backfills legacy accounts, not just brand-new ones. Onboarding calls
  /// setUsername directly when the rider picks their own handle, which
  /// makes this a no-op for them (username already set by the time this
  /// next runs).
  Future<void> _ensureUsername(User user) async {
    final email = user.email;
    if (email == null || email.isEmpty) return;
    final uid = user.uid;
    final existing = await _profiles.getProfile(uid);
    if (existing?.username != null) return;
    await _profiles.claimUsernameWithFallback(uid, _profiles.suggestUsernameBase(email));
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

  /// Claims @[username] for the signed-in rider. Lets [UsernameTakenException]/
  /// [InvalidUsernameException] propagate — unlike updateDisplayName, this
  /// one the UI needs to react to synchronously (show "that's taken," let
  /// the rider try another), not just log and move on.
  Future<void> claimUsername(String username) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _profiles.setUsername(uid: uid, username: username);
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

  /// Signs out and, on a device someone else may sign into next, makes sure
  /// nothing of this rider's is left behind to leak into the next account.
  ///
  /// docs/Issues.md §33.1/§33.10: this used to be a bare `_auth.signOut()`.
  /// Two gaps that closed:
  ///   - `GoogleSignIn().signOut()` — without it, a later `signInWithGoogle()`
  ///     on the same device could silently reauthenticate the account that
  ///     just signed out instead of showing the picker.
  ///   - The confidentiality gap itself is closed at the query layer, not
  ///     here: every "unsynced" query (`RideDao.getUnsynced`, the bikes/
  ///     maintenance queries in `SyncManager._performSync`) is now scoped to
  ///     `user_id`, so a sync started by whoever is signed in next can never
  ///     pick up rows this rider recorded but hadn't synced yet. Those rows
  ///     stay put — unsynced but no longer uploadable under a stranger's
  ///     account — until this rider signs back in on this device, at which
  ///     point they sync normally. Deliberately NOT wiping the local DB here:
  ///     that would destroy exactly the offline data durability the outbox/
  ///     local-first design exists for, on every ordinary sign-out.
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* not signed in via Google, or already signed out */}
    state = const AsyncValue.data(null);
  }

  /// Completely deletes the current rider's account:
  /// 1. Remote Firestore document and username claim
  /// 2. Local SQLite database records (rides, bikes, maintenance, etc.)
  /// 3. Firebase Auth account
  /// 4. Google Sign-In session
  ///
  /// Required by Apple App Store Review Guideline 5.1.1(v).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Delete remote profile and handle
      try {
        await _profiles.deleteUserAccount(uid);
      } catch (_) {
        // Non-fatal if offline or already removed
      }

      // 2. Wipe local SQLite data
      try {
        await DatabaseHelper.instance.deleteUserData(uid);
      } catch (_) {
        // Non-fatal
      }

      // 3. Delete Firebase Auth user (may throw FirebaseAuthException with 'requires-recent-login')
      await user.delete();

      // 4. Sign out external providers
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    });
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(firebaseAuthProvider));
});
