import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  /// Uploads an avatar image and returns its download URL. Stored at
  /// `avatars/{uid}.jpg`; overwrites the previous avatar.
  Future<String> uploadAvatar(String uid, File file) async {
    final ref = _storage.ref('avatars/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
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
