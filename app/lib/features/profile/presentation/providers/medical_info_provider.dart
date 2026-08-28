import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/medical_info_entity.dart';

const _prefsKeyPrefix = 'safe_qr_medical_info_';

/// Persisted, device-local medical info behind SafeQR (see
/// `safe_qr_payload.dart`). Deliberately `SharedPreferences`, not Firestore —
/// this feature's whole pitch is "cheap, no backend needed," and a
/// first-responder card doesn't need to sync across devices to do its job.
/// The real tradeoff, stated plainly rather than hidden: a reinstall or a
/// new device starts this blank again, same as any other
/// SharedPreferences-backed setting in this app (see `theme_style_provider`,
/// `locale_provider`).
///
/// Keyed per-uid (like `EmergencyContactsNotifier`) so signing out and back
/// in as a different rider on a shared device never shows the previous
/// rider's blood group or allergies.
class MedicalInfoNotifier extends StateNotifier<MedicalInfoEntity> {
  final String? _uid;

  MedicalInfoNotifier(this._uid) : super(const MedicalInfoEntity()) {
    if (_uid != null) _loadPersisted();
  }

  String get _prefsKey => '$_prefsKeyPrefix$_uid';

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // disposed while the read was in flight
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      state = MedicalInfoEntity.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/foreign value under this key — treat as never set rather
      // than crashing the settings screen that reads this provider.
    }
  }

  Future<void> save(MedicalInfoEntity info) async {
    if (_uid == null) return;
    state = info;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(info.toJson()));
  }
}

final medicalInfoProvider =
    StateNotifierProvider<MedicalInfoNotifier, MedicalInfoEntity>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  return MedicalInfoNotifier(uid);
});
