import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/emergency_contact_entity.dart';

const _uuid = Uuid();

final emergencyContactsProvider = StreamProvider.family<List<EmergencyContactEntity>, String>(
  (ref, uid) {
    final firestore = FirebaseFirestore.instance;
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

final emergencyContactsNotifierProvider =
    StateNotifierProvider<EmergencyContactsNotifier, AsyncValue<List<EmergencyContactEntity>>>(
  (ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) {
      return EmergencyContactsNotifier(null, ref);
    }
    return EmergencyContactsNotifier(uid, ref);
  },
);

class EmergencyContactsNotifier
    extends StateNotifier<AsyncValue<List<EmergencyContactEntity>>> {
  final String? _uid;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  EmergencyContactsNotifier(this._uid, this._ref)
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

  Future<void> addContact({
    required String name,
    required String phone,
    String? email,
  }) async {
    if (_uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .add({
        'name': name,
        'phone': phone,
        'email': email,
        'createdAt': Timestamp.now(),
      });

      await _loadContacts();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
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
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .doc(contactId)
          .update({
        'name': name,
        'phone': phone,
        'email': email,
      });

      await _loadContacts();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteContact(String contactId) async {
    if (_uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();

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
  return FirebaseFirestore.instance
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
