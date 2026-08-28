/// Builds the plain-text payload encoded into a rider's SafeQR code — a
/// scannable medical-info card a bystander or traffic police can read with
/// any phone camera, no ThrottleIQ account or app install needed on their
/// end.
///
/// Deliberately plain text, not a deep link or a JSON blob: the whole point
/// is that *any* QR scanner renders it as readable text at a glance. A deep
/// link would need the app installed and signed in to mean anything, which
/// defeats the "bystander with no relationship to this rider" use case.
///
/// Pure string-building, no Flutter/Firestore, so it's unit-testable without
/// a widget tree — same shape as `place_directions.dart`.
library;

import 'entities/medical_info_entity.dart';

/// One line of a first responder's contact, or null if there is none to show.
class SafeQrEmergencyContact {
  final String name;
  final String phone;

  const SafeQrEmergencyContact({required this.name, required this.phone});
}

/// Builds the SafeQR text payload from whatever the rider has actually
/// filled in. Every line is optional and omitted when blank — a card with
/// only a blood group set should read as one line, not four labelled blanks.
String buildSafeQrPayload({
  required String riderName,
  required MedicalInfoEntity medicalInfo,
  SafeQrEmergencyContact? emergencyContact,
}) {
  final lines = <String>['THROTTLEIQ SAFE-QR'];

  if (riderName.trim().isNotEmpty) {
    lines.add('Name: ${riderName.trim()}');
  }
  if (medicalInfo.bloodGroup.trim().isNotEmpty) {
    lines.add('Blood group: ${medicalInfo.bloodGroup.trim()}');
  }
  if (medicalInfo.allergies.trim().isNotEmpty) {
    lines.add('Allergies: ${medicalInfo.allergies.trim()}');
  }
  if (medicalInfo.conditions.trim().isNotEmpty) {
    lines.add('Conditions: ${medicalInfo.conditions.trim()}');
  }
  if (medicalInfo.medications.trim().isNotEmpty) {
    lines.add('Medications: ${medicalInfo.medications.trim()}');
  }
  if (emergencyContact != null &&
      emergencyContact.name.trim().isNotEmpty &&
      emergencyContact.phone.trim().isNotEmpty) {
    lines.add(
      'Emergency contact: ${emergencyContact.name.trim()} '
      '(${emergencyContact.phone.trim()})',
    );
  }

  return lines.join('\n');
}

/// Whether there's anything worth turning into a QR code yet — a card with
/// only the header line is not a useful scan, and `qr_flutter` would still
/// happily render one.
bool safeQrPayloadHasContent({
  required String riderName,
  required MedicalInfoEntity medicalInfo,
  SafeQrEmergencyContact? emergencyContact,
}) {
  return riderName.trim().isNotEmpty || !medicalInfo.isEmpty;
}
