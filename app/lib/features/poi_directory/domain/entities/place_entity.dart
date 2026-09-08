import 'package:equatable/equatable.dart';

enum PlaceCategory {
  fuel,
  garage,
  parts,
  aiCamera,
  police,

  /// Biker cafes, rider-friendly eateries and scenic stop-offs — the
  /// "where do we meet / where do we stop" category, as opposed to the
  /// three utilitarian ones above.
  recreation;

  String get displayName {
    switch (this) {
      case PlaceCategory.fuel:
        return 'Fuel';
      case PlaceCategory.garage:
        return 'Garage';
      case PlaceCategory.parts:
        return 'Parts';
      case PlaceCategory.aiCamera:
        return 'AI Camera';
      case PlaceCategory.police:
        return 'Police / Cop';
      case PlaceCategory.recreation:
        return 'Recreation';
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
      case PlaceCategory.aiCamera:
        return '📸';
      case PlaceCategory.police:
        return '🚓';
      case PlaceCategory.recreation:
        return '☕';
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

  /// Google Maps rating (x), e.g. 4.2, or 0.0 if not available.
  final double googleRating;

  /// Number of Google Maps reviews, or 0 if not available.
  final int googleRatingCount;

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
    this.googleRating = 0,
    this.googleRatingCount = 0,
    this.osmId,
  });

  double get averageRating {
    if (ratingCount == 0) return 0;
    return ratingSum / ratingCount;
  }

  bool get hasGoogleRating => googleRating > 0;
  bool get hasThrottleIqRating => ratingCount > 0;

  /// Formatted as "x + y" where x is Google rating and y is ThrottleIQ rating.
  String get dualRatingDisplay {
    final x = googleRating > 0 ? googleRating.toStringAsFixed(1) : '0';
    final y = ratingCount > 0 ? averageRating.toStringAsFixed(1) : '0';
    return '$x + $y';
  }

  /// Detailed subtitle showing counts for both sources.
  String get reviewsSummarySubtitle {
    if (googleRatingCount > 0 && ratingCount > 0) {
      return '$googleRatingCount Google · $ratingCount ThrottleIQ';
    } else if (googleRatingCount > 0) {
      return '$googleRatingCount Google · 0 ThrottleIQ';
    } else if (ratingCount > 0) {
      return '0 Google · $ratingCount ThrottleIQ';
    } else {
      return 'No reviews yet';
    }
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
    googleRating,
    googleRatingCount,
    osmId,
  ];
}
