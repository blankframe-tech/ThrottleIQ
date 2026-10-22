import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/domain/place_tags.dart';

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

  /// [PlaceTag] names. Absent on docs written before tags existed, which
  /// read back as an empty list.
  final List<String> tags;

  /// When this place ceases to be active (e.g. temporary cop checkpoints).
  /// Null for permanent places.
  final DateTime? expiresAt;

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
    this.tags = const [],
    this.expiresAt,
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
      tags: PlaceTag.parseAll(tags),
      expiresAt: expiresAt,
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
      tags: [
        for (final t in PlaceTag.values)
          if (entity.tags.contains(t)) t.name
      ],
      expiresAt: entity.expiresAt,
    );
  }

  factory PlaceModel.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      PlaceModel.fromMap(doc.id, doc.data()!);

  /// A Firestore doc's fields, or [toCacheJson]'s output (dates as epoch
  /// millis instead of [Timestamp]s).
  factory PlaceModel.fromMap(String id, Map<String, dynamic> data) {
    return PlaceModel(
      id: id,
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
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      ratingSum: (data['ratingSum'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      googleRating: (data['googleRating'] as num?)?.toDouble() ?? 0.0,
      googleRatingCount: (data['googleRatingCount'] as num?)?.toInt() ?? 0,
      osmId: data['osmId'],
      tags: [
        for (final t in (data['tags'] as List?) ?? const [])
          if (t is String) t,
      ],
      expiresAt: _date(data['expiresAt']),
    );
  }

  static DateTime? _date(Object? v) => v is Timestamp
      ? v.toDate()
      : v is int
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : null;

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
      // Only written when there's something to say, so a tagless place (every
      // OSM import) keeps exactly the doc shape it had before tags existed.
      if (tags.isNotEmpty) 'tags': tags,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      // Server time, so the ride cache's `updatedAt > lastPull` pull can't
      // miss a place written from a phone with a slow clock (issues §104.1).
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// [toFirestore] as plain JSON for the on-device ride cache.
  Map<String, dynamic> toCacheJson() => {
        ...toFirestore()..remove('updatedAt'),
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
      };

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
    List<String>? tags,
    DateTime? expiresAt,
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
      tags: tags ?? this.tags,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
