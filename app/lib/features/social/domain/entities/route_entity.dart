import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class RouteEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double distanceKm;
  final List<LatLng> polyline;
  final String? mapSnapshotUrl;
  final int timesRidden;
  final DateTime createdAt;
  final bool isPublic;
  final List<String> sharedWithUserIds;

  const RouteEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.distanceKm,
    required this.polyline,
    this.mapSnapshotUrl,
    this.timesRidden = 0,
    required this.createdAt,
    this.isPublic = false,
    this.sharedWithUserIds = const [],
  });

  RouteEntity copyWith({
    int? timesRidden,
    bool? isPublic,
    List<String>? sharedWithUserIds,
  }) {
    return RouteEntity(
      id: id,
      userId: userId,
      name: name,
      description: description,
      distanceKm: distanceKm,
      polyline: polyline,
      mapSnapshotUrl: mapSnapshotUrl,
      timesRidden: timesRidden ?? this.timesRidden,
      createdAt: createdAt,
      isPublic: isPublic ?? this.isPublic,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
    );
  }

  @override
  List<Object?> get props => [id, userId, createdAt];
}
