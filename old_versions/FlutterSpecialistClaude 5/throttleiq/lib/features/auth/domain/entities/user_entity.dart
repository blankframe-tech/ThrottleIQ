import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  bool get hasCompletedOnboarding => displayName != null && displayName!.isNotEmpty;

  @override
  List<Object?> get props => [id, email, displayName, photoUrl];
}
