import 'package:equatable/equatable.dart';

/// The rider-entered fields behind SafeQR (see `safe_qr_payload.dart`) — a
/// first-responder card, not a medical record: short, scannable fields only,
/// no history or documents. Device-local by design (see
/// `medical_info_provider.dart`), so there is nothing here Firestore ever
/// sees.
class MedicalInfoEntity extends Equatable {
  final String bloodGroup;
  final String allergies;
  final String conditions;
  final String medications;

  const MedicalInfoEntity({
    this.bloodGroup = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
  });

  bool get isEmpty =>
      bloodGroup.isEmpty &&
      allergies.isEmpty &&
      conditions.isEmpty &&
      medications.isEmpty;

  MedicalInfoEntity copyWith({
    String? bloodGroup,
    String? allergies,
    String? conditions,
    String? medications,
  }) {
    return MedicalInfoEntity(
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
    );
  }

  Map<String, String> toJson() => {
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'conditions': conditions,
        'medications': medications,
      };

  factory MedicalInfoEntity.fromJson(Map<String, dynamic> json) {
    return MedicalInfoEntity(
      bloodGroup: json['bloodGroup'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      conditions: json['conditions'] as String? ?? '',
      medications: json['medications'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [bloodGroup, allergies, conditions, medications];
}
