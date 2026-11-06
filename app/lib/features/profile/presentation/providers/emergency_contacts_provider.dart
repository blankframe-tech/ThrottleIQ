import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import 'package:throttleiq/core/cloud/write_ack.dart';
import 'package:throttleiq/core/cloud/firebase_providers.dart';

/// The crash-alert function texts only the first 5 contacts by doc id
/// (issues §123 C5), so the app refuses a sixth instead of silently ignoring it.
const maxEmergencyContacts = 5;

final emergencyContactsProvider =
    StreamProvider.family<List<EmergencyContactEntity>, String>(
  (ref, uid) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('users')
        .doc(uid)
        .collection('emergencyContacts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return EmergencyContactEntity(
          id: doc.id,
          name: data['name'] as String,
          phone: data['phone'] as String,
          email: data['email'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        );
      }).toList();
    });
  },
);

final emergencyContactsNotifierProvider = StateNotifierProvider<
    EmergencyContactsNotifier, AsyncValue<List<EmergencyContactEntity>>>(
  (ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) {
      return EmergencyContactsNotifier(null, ref.watch(firestoreProvider));
    }
    return EmergencyContactsNotifier(uid, ref.watch(firestoreProvider));
  },
);

class EmergencyContactsNotifier
    extends StateNotifier<AsyncValue<List<EmergencyContactEntity>>> {
  final String? _uid;
  final FirebaseFirestore _firestore;

  EmergencyContactsNotifier(this._uid, this._firestore)
      : super(const AsyncValue.loading()) {
    if (_uid != null) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    if (_uid == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .orderBy('createdAt', descending: true)
          .get();

      final contacts = snapshot.docs.map((doc) {
        final data = doc.data();
        return EmergencyContactEntity(
          id: doc.id,
          name: data['name'] as String,
          phone: data['phone'] as String,
          email: data['email'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        );
      }).toList();

      state = AsyncValue.data(contacts);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Returns false when the cap is hit and nothing was added.
  Future<bool> addContact({
    required String name,
    required String phone,
    String? email,
  }) async {
    if (_uid == null) return false;
    if ((state.valueOrNull?.length ?? 0) >= maxEmergencyContacts) return false;

    try {
      await ackOrQueued(_firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .add({
        'name': name,
        'phone': phone,
        'email': email,
        'createdAt': Timestamp.now(),
      }));

      await _loadContacts();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<void> updateContact({
    required String contactId,
    required String name,
    required String phone,
    String? email,
  }) async {
    if (_uid == null) return;

    try {
      await ackOrQueued(_firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .doc(contactId)
          .update({
        'name': name,
        'phone': phone,
        'email': email,
      }));

      await _loadContacts();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteContact(String contactId) async {
    if (_uid == null) return;

    try {
      await ackOrQueued(_firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete());

      await _loadContacts();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Convenience provider for current user's emergency contacts
final myEmergencyContactsProvider =
    StreamProvider<List<EmergencyContactEntity>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream.value([]);
  }
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('emergencyContacts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return EmergencyContactEntity(
        id: doc.id,
        name: data['name'] as String,
        phone: data['phone'] as String,
        email: data['email'] as String?,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
      );
    }).toList();
  });
});
