import 'package:equatable/equatable.dart';

class RideCommentEntity extends Equatable {
  final String id;
  final String rideId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RideCommentEntity({
    required this.id,
    required this.rideId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  RideCommentEntity copyWith({
    String? text,
    DateTime? updatedAt,
  }) {
    return RideCommentEntity(
      id: id,
      rideId: rideId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, rideId, userId, createdAt];
}
