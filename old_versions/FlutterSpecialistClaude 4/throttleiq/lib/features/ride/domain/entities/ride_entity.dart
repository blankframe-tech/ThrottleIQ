import 'package:equatable/equatable.dart';

enum RideStatus { active, paused, completed }

class RideEntity extends Equatable {
  final String id;
  final String userId;
  final String bikeId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceM;
  final double? avgSpeedMs;
  final double? maxSpeedMs;
  final int? durationSeconds;
  final int hardBrakeCount;
  final int rapidAccelCount;
  final int highJerkCount;
  final RideStatus status;
  final String? mapSnapshotPath;

  const RideEntity({
    required this.id,
    required this.userId,
    required this.bikeId,
    required this.startTime,
    this.endTime,
    this.distanceM = 0,
    this.avgSpeedMs,
    this.maxSpeedMs,
    this.durationSeconds,
    this.hardBrakeCount = 0,
    this.rapidAccelCount = 0,
    this.highJerkCount = 0,
    this.status = RideStatus.active,
    this.mapSnapshotPath,
  });

  double get distanceKm => distanceM / 1000;
  double get avgSpeedKmh => (avgSpeedMs ?? 0) * 3.6;
  double get maxSpeedKmh => (maxSpeedMs ?? 0) * 3.6;

  RideEntity copyWith({
    double? distanceM,
    double? avgSpeedMs,
    double? maxSpeedMs,
    int? durationSeconds,
    int? hardBrakeCount,
    int? rapidAccelCount,
    int? highJerkCount,
    RideStatus? status,
    DateTime? endTime,
    String? mapSnapshotPath,
  }) {
    return RideEntity(
      id: id,
      userId: userId,
      bikeId: bikeId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      distanceM: distanceM ?? this.distanceM,
      avgSpeedMs: avgSpeedMs ?? this.avgSpeedMs,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      hardBrakeCount: hardBrakeCount ?? this.hardBrakeCount,
      rapidAccelCount: rapidAccelCount ?? this.rapidAccelCount,
      highJerkCount: highJerkCount ?? this.highJerkCount,
      status: status ?? this.status,
      mapSnapshotPath: mapSnapshotPath ?? this.mapSnapshotPath,
    );
  }

  @override
  List<Object?> get props => [id, userId, bikeId, startTime, status];
}
