import '../../domain/entities/bike_entity.dart';

class BikeModel {
  static BikeEntity fromMap(Map<String, dynamic> m) => BikeEntity(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        brand: m['brand'] as String,
        model: m['model'] as String,
        year: m['year'] as int?,
        cc: m['cc'] as int?,
        imagePath: m['image_path'] as String?,
        isActive: (m['is_active'] as int) == 1,
        totalDistanceM: (m['total_distance_m'] as num).toDouble(),
        rideCount: m['ride_count'] as int,
        lastRideAt: m['last_ride_at'] != null
            ? DateTime.parse(m['last_ride_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static Map<String, dynamic> toMap(BikeEntity e) => {
        'id': e.id,
        'user_id': e.userId,
        'brand': e.brand,
        'model': e.model,
        'year': e.year,
        'cc': e.cc,
        'image_path': e.imagePath,
        'is_active': e.isActive ? 1 : 0,
        'total_distance_m': e.totalDistanceM,
        'ride_count': e.rideCount,
        'last_ride_at': e.lastRideAt?.toIso8601String(),
        'synced': 0,
        'created_at': e.createdAt.toIso8601String(),
      };
}
