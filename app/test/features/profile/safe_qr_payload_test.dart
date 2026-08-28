import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/domain/entities/medical_info_entity.dart';
import 'package:throttleiq/features/profile/domain/safe_qr_payload.dart';

void main() {
  group('buildSafeQrPayload', () {
    test('includes every filled-in field', () {
      final payload = buildSafeQrPayload(
        riderName: 'Rahim Uddin',
        medicalInfo: const MedicalInfoEntity(
          bloodGroup: 'O+',
          allergies: 'Penicillin',
          conditions: 'Asthma',
          medications: 'Inhaler',
        ),
        emergencyContact: const SafeQrEmergencyContact(
          name: 'Karim Uddin',
          phone: '+8801700000000',
        ),
      );

      expect(payload, contains('Name: Rahim Uddin'));
      expect(payload, contains('Blood group: O+'));
      expect(payload, contains('Allergies: Penicillin'));
      expect(payload, contains('Conditions: Asthma'));
      expect(payload, contains('Medications: Inhaler'));
      expect(payload,
          contains('Emergency contact: Karim Uddin (+8801700000000)'));
    });

    test('omits blank fields rather than printing empty labels', () {
      final payload = buildSafeQrPayload(
        riderName: 'Rahim Uddin',
        medicalInfo: const MedicalInfoEntity(bloodGroup: 'O+'),
      );

      expect(payload, contains('Name: Rahim Uddin'));
      expect(payload, contains('Blood group: O+'));
      expect(payload, isNot(contains('Allergies:')));
      expect(payload, isNot(contains('Conditions:')));
      expect(payload, isNot(contains('Medications:')));
      expect(payload, isNot(contains('Emergency contact:')));
    });

    test('omits the emergency contact line when only half is filled in', () {
      final payload = buildSafeQrPayload(
        riderName: 'Rahim Uddin',
        medicalInfo: const MedicalInfoEntity(),
        emergencyContact: const SafeQrEmergencyContact(name: 'Karim', phone: ''),
      );

      expect(payload, isNot(contains('Emergency contact:')));
    });

    test('always leads with the header line even with nothing else set', () {
      final payload = buildSafeQrPayload(
        riderName: '',
        medicalInfo: const MedicalInfoEntity(),
      );

      expect(payload, 'THROTTLEIQ SAFE-QR');
    });

    test('trims whitespace-only fields as if they were empty', () {
      final payload = buildSafeQrPayload(
        riderName: '   ',
        medicalInfo: const MedicalInfoEntity(bloodGroup: '  '),
      );

      expect(payload, 'THROTTLEIQ SAFE-QR');
    });
  });

  group('safeQrPayloadHasContent', () {
    test('is false with no name and no medical info', () {
      expect(
        safeQrPayloadHasContent(
          riderName: '',
          medicalInfo: const MedicalInfoEntity(),
        ),
        isFalse,
      );
    });

    test('is true once a name is set', () {
      expect(
        safeQrPayloadHasContent(
          riderName: 'Rahim',
          medicalInfo: const MedicalInfoEntity(),
        ),
        isTrue,
      );
    });

    test('is true once any medical field is set', () {
      expect(
        safeQrPayloadHasContent(
          riderName: '',
          medicalInfo: const MedicalInfoEntity(bloodGroup: 'O+'),
        ),
        isTrue,
      );
    });
  });
}
