import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/medical_info_entity.dart';
import 'package:throttleiq/core/cloud/write_ack.dart';
import 'package:throttleiq/core/utils/error_reporter.dart';

/// Pre-sync builds kept the card in SharedPreferences under this key; read
/// once to move it up, then removed.
const _legacyPrefsKeyPrefix = 'safe_qr_medical_info_';

/// Medical info behind SafeQR (see `safe_qr_payload.dart`), stored in
/// `users/{uid}/private/medical` so a reinstall or a new phone gets it back.
/// `private/*` is owner-only in `firestore.rules`, and account erasure
/// deletes `users/{uid}` recursively, so it goes with the account.
///
/// Keyed per-uid so signing in as a different rider on a shared device never
/// shows the previous rider's blood group or allergies.
class MedicalInfoNotifier extends StateNotifier<MedicalInfoEntity> {
  final String? _uid;
  final FirebaseFirestore _firestore;

  MedicalInfoNotifier(this._uid, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const MedicalInfoEntity()) {
    if (_uid != null) _load();
  }

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('private')
      .doc('medical');

  String get _legacyKey => '$_legacyPrefsKeyPrefix$_uid';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = _decode(prefs.getString(_legacyKey));
    try {
      final snap = await _doc.get();
      if (!mounted) return; // disposed while the read was in flight
      if (snap.exists) {
        state = MedicalInfoEntity.fromJson(snap.data()!);
      } else if (legacy != null) {
        state = legacy;
        await ackOrQueued(_doc.set(legacy.toJson()));
      }
      // Only drop the local copy once Firestore has (or has queued) a copy.
      if (legacy != null) await prefs.remove(_legacyKey);
    } catch (e, st) {
      // Offline with nothing cached: show the local copy if there is one,
      // and keep it for the next launch to move up.
      reportSilently(e, st, where: 'medicalInfo.load');
      if (mounted && legacy != null) state = legacy;
    }
  }

  MedicalInfoEntity? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return MedicalInfoEntity.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      // Corrupt/foreign value: treat as never set rather than crashing the
      // settings screen that reads this provider.
      reportSilently(e, st, where: 'medicalInfo.decode');
      return null;
    }
  }

  Future<void> save(MedicalInfoEntity info) async {
    if (_uid == null) return;
    state = info;
    await ackOrQueued(_doc.set(info.toJson()));
  }
}

final medicalInfoProvider =
    StateNotifierProvider<MedicalInfoNotifier, MedicalInfoEntity>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  return MedicalInfoNotifier(uid);
});
