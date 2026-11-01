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

  /// Phone time when written, display only (issue #157, `displayTime`).
  final DateTime? writtenAt;

  /// Saved on this phone but not uploaded yet (Firestore `hasPendingWrites`,
  /// issue #158): only this rider can see it so far.
  final bool hasPendingWrites;

  const RideCommentEntity({
    required this.id,
    required this.rideId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.writtenAt,
    this.hasPendingWrites = false,
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
      writtenAt: writtenAt,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  List<Object?> get props => [id, rideId, userId, createdAt];
}
