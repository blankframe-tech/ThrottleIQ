import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/profile/domain/entities/medical_info_entity.dart';
import 'package:throttleiq/features/profile/presentation/providers/medical_info_provider.dart';

/// SafeQR medical info lives in users/{uid}/private/medical so a reinstall
/// gets it back; a pre-sync on-device copy is moved up once.
void main() {
  const info = MedicalInfoEntity(bloodGroup: 'O+', allergies: 'penicillin');
  const legacyKey = 'safe_qr_medical_info_u1';

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('save lands in Firestore and a fresh notifier reads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final fs = FakeFirebaseFirestore();
    await MedicalInfoNotifier('u1', firestore: fs).save(info);

    final doc = await fs.doc('users/u1/private/medical').get();
    expect(doc.data(), info.toJson());

    // A "reinstall": empty prefs, new notifier, same account.
    final again = MedicalInfoNotifier('u1', firestore: fs);
    await settle();
    expect(again.state, info);
  });

  test('a pre-sync local copy moves to Firestore and leaves prefs', () async {
    SharedPreferences.setMockInitialValues(
        {legacyKey: json.encode(info.toJson())});
    final fs = FakeFirebaseFirestore();
    final n = MedicalInfoNotifier('u1', firestore: fs);
    await settle();

    expect(n.state, info);
    expect(
        (await fs.doc('users/u1/private/medical').get()).data(), info.toJson());
    expect(
        (await SharedPreferences.getInstance()).getString(legacyKey), isNull);
  });

  test('an existing cloud copy wins over a stale local one', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: json.encode(const MedicalInfoEntity(bloodGroup: 'A-').toJson())
    });
    final fs = FakeFirebaseFirestore();
    await fs.doc('users/u1/private/medical').set(info.toJson());
    final n = MedicalInfoNotifier('u1', firestore: fs);
    await settle();
    expect(n.state, info);
  });

  test('no uid: nothing is read or written', () async {
    SharedPreferences.setMockInitialValues({});
    final fs = FakeFirebaseFirestore();
    final n = MedicalInfoNotifier(null, firestore: fs);
    await n.save(info);
    expect(n.state, const MedicalInfoEntity());
    expect((await fs.collection('users').get()).docs, isEmpty);
  });
}
