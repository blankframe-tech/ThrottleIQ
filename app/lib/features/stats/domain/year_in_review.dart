import '../../ride/domain/entities/ride_entity.dart';

/// One calendar year of a rider's local rides, for the shareable card.
class YearInReview {
  final int year;
  final int rideCount;
  final double distanceKm;
  final double longestRideKm;

  /// The bike with the most rides that year (distance breaks a tie); null
  /// when the year has no rides.
  final String? favouriteBikeId;

  const YearInReview({
    required this.year,
    required this.rideCount,
    required this.distanceKm,
    required this.longestRideKm,
    required this.favouriteBikeId,
  });
}

/// Years that have at least one ride, newest first.
List<int> rideYears(List<RideEntity> rides) =>
    ({for (final r in rides) r.startTime.year}.toList()
      ..sort((a, b) => b.compareTo(a)));

YearInReview computeYearInReview(List<RideEntity> rides, int year) {
  final inYear = rides.where((r) => r.startTime.year == year);
  var distanceKm = 0.0;
  var longestKm = 0.0;
  final countByBike = <String, int>{};
  final kmByBike = <String, double>{};
  for (final r in inYear) {
    distanceKm += r.distanceKm;
    if (r.distanceKm > longestKm) longestKm = r.distanceKm;
    countByBike[r.bikeId] = (countByBike[r.bikeId] ?? 0) + 1;
    kmByBike[r.bikeId] = (kmByBike[r.bikeId] ?? 0) + r.distanceKm;
  }
  String? favourite;
  for (final id in countByBike.keys) {
    if (favourite == null ||
        countByBike[id]! > countByBike[favourite]! ||
        (countByBike[id] == countByBike[favourite] &&
            kmByBike[id]! > kmByBike[favourite]!)) {
      favourite = id;
    }
  }
  return YearInReview(
    year: year,
    rideCount: countByBike.values.fold(0, (a, b) => a + b),
    distanceKm: distanceKm,
    longestRideKm: longestKm,
    favouriteBikeId: favourite,
  );
}
