import 'package:latlong2/latlong.dart';

import '../../domain/entities/route_entity.dart';

class RouteModel {
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

  RouteModel({
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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'distanceKm': distanceKm,
      'polyline': polyline
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'mapSnapshotUrl': mapSnapshotUrl,
      'timesRidden': timesRidden,
      'createdAt': createdAt,
      'isPublic': isPublic,
      'sharedWithUserIds': sharedWithUserIds,
    };
  }

  factory RouteModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    final polylineList = (data['polyline'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(
              (point) => LatLng(
                point['lat'] as double,
                point['lng'] as double,
              ),
            )
            .toList() ??
        [];

    return RouteModel(
      id: docId,
      userId: data['userId'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      polyline: polylineList,
      mapSnapshotUrl: data['mapSnapshotUrl'] as String?,
      timesRidden: (data['timesRidden'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as dynamic).toDate() ?? DateTime.now(),
      isPublic: data['isPublic'] as bool? ?? false,
      sharedWithUserIds:
          (data['sharedWithUserIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  RouteEntity toEntity() {
    return RouteEntity(
      id: id,
      userId: userId,
      name: name,
      description: description,
      distanceKm: distanceKm,
      polyline: polyline,
      mapSnapshotUrl: mapSnapshotUrl,
      timesRidden: timesRidden,
      createdAt: createdAt,
      isPublic: isPublic,
      sharedWithUserIds: sharedWithUserIds,
    );
  }
}
