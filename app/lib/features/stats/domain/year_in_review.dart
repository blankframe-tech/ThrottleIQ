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

  /// Total ride duration in seconds; rides with no duration count as zero.
  final int rideSeconds;

  /// Kilometres per month, January first (always 12 entries).
  final List<double> monthKm;

  /// The month (1-12) with the most kilometres; null without rides.
  final int? busiestMonth;

  /// Kilometres over the same span of the year before: the whole year, or,
  /// for a year still in progress, up to the same date. Null when the rider
  /// has no rides in that span, so there is nothing to compare.
  final double? previousKm;

  const YearInReview({
    required this.year,
    required this.rideCount,
    required this.distanceKm,
    required this.longestRideKm,
    required this.favouriteBikeId,
    this.rideSeconds = 0,
    this.monthKm = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.busiestMonth,
    this.previousKm,
  });

  /// Distance change against [previousKm] as a fraction (0.25 = +25%); null
  /// when there is nothing to compare against.
  double? get changeVsPrevious => previousKm == null || previousKm == 0
      ? null
      : (distanceKm - previousKm!) / previousKm!;
}

/// Years that have at least one ride, newest first.
List<int> rideYears(List<RideEntity> rides) =>
    ({for (final r in rides) r.startTime.year}.toList()
      ..sort((a, b) => b.compareTo(a)));

/// [now] decides whether [year] is still in progress, which limits the
/// year-before comparison to the same date.
YearInReview computeYearInReview(List<RideEntity> rides, int year,
    {DateTime? now}) {
  now ??= DateTime.now();
  final inYear = rides.where((r) => r.startTime.year == year);
  var distanceKm = 0.0;
  var longestKm = 0.0;
  var seconds = 0;
  final monthKm = List<double>.filled(12, 0);
  final countByBike = <String, int>{};
  final kmByBike = <String, double>{};
  for (final r in inYear) {
    distanceKm += r.distanceKm;
    if (r.distanceKm > longestKm) longestKm = r.distanceKm;
    seconds += r.durationSeconds ?? 0;
    monthKm[r.startTime.month - 1] += r.distanceKm;
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
  int? busiest;
  for (var m = 0; m < 12; m++) {
    if (monthKm[m] > 0 && (busiest == null || monthKm[m] > monthKm[busiest])) {
      busiest = m;
    }
  }
  final cutoff = year == now.year
      ? DateTime(year - 1, now.month, now.day + 1)
      : DateTime(year);
  final before = rides
      .where(
          (r) => r.startTime.year == year - 1 && r.startTime.isBefore(cutoff))
      .toList();
  return YearInReview(
    year: year,
    rideCount: countByBike.values.fold(0, (a, b) => a + b),
    distanceKm: distanceKm,
    longestRideKm: longestKm,
    favouriteBikeId: favourite,
    rideSeconds: seconds,
    monthKm: monthKm,
    busiestMonth: busiest == null ? null : busiest + 1,
    previousKm: before.isEmpty
        ? null
        : before.fold<double>(0, (a, r) => a + r.distanceKm),
  );
}
