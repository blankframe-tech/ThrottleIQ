import 'package:equatable/equatable.dart';

import '../place_tags.dart';

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

  /// Speed cameras and police checkposts are road-safety hazards, not
  /// destinations: the Places hub keeps them out of the category ribbon and
  /// surfaces them through the Highway Radar instead, and they carry no
  /// ratings (nobody "rates" a checkpost).
  bool get isSafetyPoint =>
      this == PlaceCategory.aiCamera || this == PlaceCategory.police;

  /// The categories a rider browses as stops, in ribbon order.
  static List<PlaceCategory> get destinations =>
      [for (final c in values) if (!c.isSafetyPoint) c];

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

  /// Rider-facing facts (24/7, 95 octane, EFI diagnostics…). Empty for every
  /// place written before tags existed — see [PlaceTag.parseAll].
  final Set<PlaceTag> tags;

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
    this.tags = const {},
  });

  double get averageRating {
    if (ratingCount == 0) return 0;
    return ratingSum / ratingCount;
  }

  bool get hasGoogleRating => googleRating > 0;
  bool get hasThrottleIqRating => ratingCount > 0;

  /// Minimum ThrottleIQ average for the "Rider Approved" badge.
  static const double riderApprovedMinAverage = 4.5;

  /// Minimum number of ThrottleIQ reviews behind that average — one rider's
  /// five stars is an anecdote, not a reputation.
  static const int riderApprovedMinCount = 5;

  /// Rated at least [riderApprovedMinAverage] by at least
  /// [riderApprovedMinCount] ThrottleIQ riders. Google's rating plays no part:
  /// the badge is the riders' own verdict.
  bool get isRiderApproved =>
      !category.isSafetyPoint &&
      ratingCount >= riderApprovedMinCount &&
      averageRating >= riderApprovedMinAverage;

  /// The score list sorting ranks by: the ThrottleIQ average when riders have
  /// rated it, else Google's, else 0. Riders' own ratings win because they
  /// rate the place *as a rider* (bike parking, whether the garage knows
  /// EFI) rather than as a car driver.
  double get sortRating => hasThrottleIqRating ? averageRating : googleRating;

  /// Whether this place has any review at all, from either source.
  ///
  /// The screens ask this instead of comparing
  /// [reviewsSummarySubtitle] against its English "No reviews yet" — that
  /// branch is the one piece of prose in here, and an entity has no
  /// `AppLocalizations` to translate it with. The counts branch needs none:
  /// it is two numbers and two brand names.
  bool get hasAnyReviews => googleRatingCount > 0 || ratingCount > 0;

  /// Detailed subtitle showing counts for both sources.
  ///
  /// The empty case still returns English; it is a diagnostic and a fixture in
  /// `place_entity_test.dart`. The UI never shows it — see [hasAnyReviews].
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
    tags,
  ];
}
