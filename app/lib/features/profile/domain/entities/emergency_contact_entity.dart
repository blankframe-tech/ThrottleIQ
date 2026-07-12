import 'package:equatable/equatable.dart';

class EmergencyContactEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final DateTime createdAt;

  const EmergencyContactEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.createdAt,
  });

  EmergencyContactEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    DateTime? createdAt,
  }) {
    return EmergencyContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, createdAt];
}
