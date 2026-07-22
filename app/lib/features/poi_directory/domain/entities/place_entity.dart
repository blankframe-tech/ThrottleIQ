import 'package:equatable/equatable.dart';

enum PlaceCategory {
  fuel,
  garage,
  parts;

  String get displayName {
    switch (this) {
      case PlaceCategory.fuel:
        return 'Fuel';
      case PlaceCategory.garage:
        return 'Garage';
      case PlaceCategory.parts:
        return 'Parts';
    }
  }

  String get icon {
    switch (this) {
      case PlaceCategory.fuel:
        return '⛽';
      case PlaceCategory.garage:
        return '🔧';
      case PlaceCategory.parts:
        return '🛒';
    }
  }

  static PlaceCategory fromString(String value) {
    return PlaceCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PlaceCategory.fuel,
    );
  }
}

class PlaceEntity extends Equatable {
  final String id;
  final String name;
  final PlaceCategory category;
  final double latitude;
  final double longitude;
  final String geohash;
  final String address;
  final String? phone;
  final String? hours;
  final List<String> photoUrls;
  final bool verified;
  final String createdBy;
  final DateTime createdAt;
  final double ratingSum;
  final int ratingCount;

  /// OSM node id (e.g. `"node/12345"`) when this place was imported from
  /// the Overpass API — null for rider-submitted places. Lets the import
  /// flow check what's already been pulled in without re-creating
  /// duplicates on a second "Import nearby" tap.
  final String? osmId;

  const PlaceEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.address,
    this.phone,
    this.hours,
    this.photoUrls = const [],
    this.verified = false,
    required this.createdBy,
    required this.createdAt,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.osmId,
  });

  double get averageRating {
    if (ratingCount == 0) return 0;
    return ratingSum / ratingCount;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    latitude,
    longitude,
    geohash,
    address,
    phone,
    hours,
    photoUrls,
    verified,
    createdBy,
    createdAt,
    ratingSum,
    ratingCount,
    osmId,
  ];
}
