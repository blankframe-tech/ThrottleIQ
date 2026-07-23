import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/cloudinary_upload_service.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../models/user_profile_model.dart';

/// Reads/writes the public `users/{uid}` profile doc, handles unique @username
/// reservation, avatar uploads, and rider search (by username prefix / exact
/// email).
class ProfileRepository {
  static final ProfileRepository _instance = ProfileRepository._internal();
  factory ProfileRepository() => _instance;
  ProfileRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryUploadService _uploadService = CloudinaryUploadService();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// `usernames/{lowercaseHandle}` → { uid }. A reservation collection that
  /// makes @handles globally unique and gives an O(1) handle→uid lookup for
  /// exact search without exposing the whole users collection.
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection('usernames');

  Future<UserProfileEntity?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfileModel.fromFirestore(doc.data()!, uid);
  }

  Stream<UserProfileEntity?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map(
        (doc) => doc.exists ? UserProfileModel.fromFirestore(doc.data()!, uid) : null);
  }

  /// Idempotently seeds the profile doc from the FirebaseAuth user. Safe to
  /// call on every login / onboarding — uses merge so it never clobbers
  /// nickname/bio/username the rider set later, and only fills the counters on
  /// first creation.
  Future<void> ensureProfile(User user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    final existing = snap.data() ?? const {};
    await ref.set({
      'displayName': user.displayName ?? existing['displayName'] ?? '',
      if (user.photoURL != null && existing['photoUrl'] == null)
        'photoUrl': user.photoURL,
      if (user.email != null) ...{
        'email': user.email,
        'emailLower': user.email!.toLowerCase(),
      },
      if (!snap.exists) ...{
        'followerCount': 0,
        'followingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Updates the caller's own profile fields (never the counters).
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? nickname,
    String? bio,
    String? photoUrl,
  }) async {
    await _users.doc(uid).set(
          UserProfileModel.editableFields(
            displayName: displayName,
            nickname: nickname,
            bio: bio,
            photoUrl: photoUrl,
          ),
          SetOptions(merge: true),
        );
  }

  /// Claims a unique @username for [uid]. Throws [UsernameTakenException] if
  /// another rider already holds it. Releases the rider's previous handle.
  Future<void> setUsername({required String uid, required String username}) async {
    final handle = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(handle)) {
      throw const InvalidUsernameException();
    }
    final newRef = _usernames.doc(handle);
    final userRef = _users.doc(uid);

    await _firestore.runTransaction((txn) async {
      final claim = await txn.get(newRef);
      if (claim.exists && claim.data()!['uid'] != uid) {
        throw const UsernameTakenException();
      }
      final userSnap = await txn.get(userRef);
      final prev = userSnap.data()?['usernameLower'] as String?;

      txn.set(newRef, {'uid': uid});
      txn.set(
        userRef,
        {
          'username': username.trim(),
          'usernameLower': handle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (prev != null && prev != handle) {
        txn.delete(_usernames.doc(prev));
      }
    });
  }

  /// Derives a candidate @handle from an email's local part (before the
  /// `@`): lowercased, stripped to `[a-z0-9_]`, clamped to setUsername's
  /// 3-20 length window. Padded with trailing zeros if the sanitized result
  /// is under 3 chars (e.g. an email like "a@x.com").
  String suggestUsernameBase(String email) {
    final local = email.split('@').first.toLowerCase();
    var base = local.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (base.length > 20) base = base.substring(0, 20);
    while (base.length < 3) {
      base += '0';
    }
    return base;
  }

  /// Best-effort: claims [base] for [uid], or [base] with a random numeric
  /// suffix appended if it's taken, retrying a handful of times. Used both
  /// to prefill onboarding's username field and as the no-username-chosen
  /// fallback (see AuthNotifier._seedProfile) so every rider ends up with a
  /// handle even if they never visit the username field themselves —
  /// "assigned their email name, and if that's taken, append [something] to
  /// it," per spec.
  Future<String?> claimUsernameWithFallback(String uid, String base) async {
    final rnd = Random();
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = attempt == 0 ? base : '${base.substring(0, base.length.clamp(0, 16))}${rnd.nextInt(9000) + 100}';
      try {
        await setUsername(uid: uid, username: candidate);
        return candidate;
      } on UsernameTakenException {
        continue;
      } on InvalidUsernameException {
        return null;
      }
    }
    return null;
  }

  /// Denormalized total-km/total-rides/earned-badge-ids snapshot, written by
  /// the owner's own device whenever a ride finalizes (see
  /// RideRecordingNotifier.stopRide). Lets a public profile show real stats
  /// without opening up the owner-only `rides`/`bikes` subcollections to
  /// cross-user reads — those can carry more than a viewer should see
  /// (exact ride times, etc.), whereas this is just three harmless numbers
  /// gated by the same [visibility] tier as the rest of the profile doc.
  Future<void> updatePublicStats({
    required String uid,
    required double totalDistanceKm,
    required int totalRides,
    required List<String> badgeIds,
  }) async {
    await _users.doc(uid).set({
      'publicStats': {
        'totalDistanceKm': totalDistanceKm,
        'totalRides': totalRides,
        'badgeIds': badgeIds,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sets who can view this rider's profile doc (and hence [publicStats]):
  /// 'public' (default — any signed-in rider), 'mutual' (only riders who
  /// follow each other), or 'private' (owner only). Enforced by
  /// firestore.rules, not just the client UI.
  Future<void> setVisibility({required String uid, required String visibility}) async {
    assert(['public', 'mutual', 'private'].contains(visibility));
    await _users.doc(uid).set({
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Uploads an avatar image (via Cloudinary — see [CloudinaryUploadService])
  /// and returns its public URL. Each upload gets a fresh URL; the previous
  /// avatar image is simply orphaned rather than overwritten in place.
  Future<String> uploadAvatar(String uid, File file) {
    return _uploadService.upload(file, folder: 'avatars/$uid');
  }

  /// Prefix search on @username (case-insensitive). Empty query → [].
  Future<List<UserProfileEntity>> searchByUsername(String query,
      {int limit = 20}) async {
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) return [];
    final snap = await _users
        .where('usernameLower', isGreaterThanOrEqualTo: q)
        .where('usernameLower', isLessThan: q + String.fromCharCode(0xf8ff))
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => UserProfileModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  /// Exact-match search by email.
  Future<List<UserProfileEntity>> searchByEmail(String email,
      {int limit = 10}) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return [];
    final snap =
        await _users.where('emailLower', isEqualTo: e).limit(limit).get();
    return snap.docs
        .map((d) => UserProfileModel.fromFirestore(d.data(), d.id))
        .toList();
  }
}

class UsernameTakenException implements Exception {
  const UsernameTakenException();
  @override
  String toString() => 'That username is already taken.';
}

class InvalidUsernameException implements Exception {
  const InvalidUsernameException();
  @override
  String toString() =>
      'Usernames must be 3-20 characters: letters, numbers or underscore.';
}
