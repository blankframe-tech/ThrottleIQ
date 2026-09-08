import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';

class PlaceModel {
  final String id;
  final String name;
  final String category;
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
  final double googleRating;
  final int googleRatingCount;
  final String? osmId;

  const PlaceModel({
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
    this.googleRating = 0,
    this.googleRatingCount = 0,
    this.osmId,
  });

  PlaceEntity toEntity() {
    return PlaceEntity(
      id: id,
      name: name,
      category: PlaceCategory.fromString(category),
      latitude: latitude,
      longitude: longitude,
      geohash: geohash,
      address: address,
      phone: phone,
      hours: hours,
      photoUrls: photoUrls,
      verified: verified,
      createdBy: createdBy,
      createdAt: createdAt,
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      googleRating: googleRating,
      googleRatingCount: googleRatingCount,
      osmId: osmId,
    );
  }

  factory PlaceModel.fromEntity(PlaceEntity entity) {
    return PlaceModel(
      id: entity.id,
      name: entity.name,
      category: entity.category.name,
      latitude: entity.latitude,
      longitude: entity.longitude,
      geohash: entity.geohash,
      address: entity.address,
      phone: entity.phone,
      hours: entity.hours,
      photoUrls: entity.photoUrls,
      verified: entity.verified,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      ratingSum: entity.ratingSum,
      ratingCount: entity.ratingCount,
      googleRating: entity.googleRating,
      googleRatingCount: entity.googleRatingCount,
      osmId: entity.osmId,
    );
  }

  factory PlaceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PlaceModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'fuel',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      geohash: data['geohash'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'],
      hours: data['hours'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      verified: data['verified'] ?? false,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ratingSum: (data['ratingSum'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      googleRating: (data['googleRating'] as num?)?.toDouble() ?? 0.0,
      googleRatingCount: (data['googleRatingCount'] as num?)?.toInt() ?? 0,
      osmId: data['osmId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'address': address,
      'phone': phone,
      'hours': hours,
      'photoUrls': photoUrls,
      'verified': verified,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
      'googleRating': googleRating,
      'googleRatingCount': googleRatingCount,
      'osmId': osmId,
    };
  }

  PlaceModel copyWith({
    String? id,
    String? name,
    String? category,
    double? latitude,
    double? longitude,
    String? geohash,
    String? address,
    String? phone,
    String? hours,
    List<String>? photoUrls,
    bool? verified,
    String? createdBy,
    DateTime? createdAt,
    double? ratingSum,
    int? ratingCount,
    double? googleRating,
    int? googleRatingCount,
    String? osmId,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      photoUrls: photoUrls ?? this.photoUrls,
      verified: verified ?? this.verified,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      ratingSum: ratingSum ?? this.ratingSum,
      ratingCount: ratingCount ?? this.ratingCount,
      googleRating: googleRating ?? this.googleRating,
      googleRatingCount: googleRatingCount ?? this.googleRatingCount,
      osmId: osmId ?? this.osmId,
    );
  }
}
