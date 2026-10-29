import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place `app/lib` reads the Firebase singletons (issues §83.13).
/// Code with a `Ref` uses these; tests override them with fakes.
/// `test/core/cloud/firebase_instance_ratchet_test.dart` fails on new direct
/// `.instance` uses elsewhere.
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// The signed-in uid, or null. Rebuilds when the uid changes (sign-in,
/// sign-out, account switch), not on profile updates.
final currentUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  final sub = auth.authStateChanges().listen((user) {
    if (user?.uid != uid) ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);
  return uid;
});
