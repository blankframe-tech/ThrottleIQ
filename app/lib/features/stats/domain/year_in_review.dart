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

  /// Rides on [favouriteBikeId] that year.
  final int favouriteBikeRides;

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

  /// True when [year] is the current year at the time of the calculation,
  /// so the card can say "so far".
  final bool inProgress;

  /// When the longest ride started, and the saved route it followed, if any.
  final DateTime? longestRideDate;
  final String? longestRideRoute;

  /// The year's top speed (km/h, 0 without speed data) and its ride's date.
  final double topSpeedKmh;
  final DateTime? topSpeedDate;

  /// Metres climbed over the year; rides without elevation data add nothing.
  final double climbM;

  /// Peak estimated lean angle in degrees; null when no ride measured it.
  final double? maxLeanDeg;

  /// Kilometres per calendar day, 1 January first (365 or 366 entries; empty
  /// for a default-constructed review).
  final List<double> dayKm;

  /// Rides per weekday, Monday first (7 entries).
  final List<int> weekdayRides;

  /// Rides per starting hour of the day, midnight first (24 entries).
  final List<int> hourRides;

  const YearInReview({
    required this.year,
    required this.rideCount,
    required this.distanceKm,
    required this.longestRideKm,
    required this.favouriteBikeId,
    this.favouriteBikeRides = 0,
    this.rideSeconds = 0,
    this.monthKm = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.busiestMonth,
    this.previousKm,
    this.inProgress = false,
    this.longestRideDate,
    this.longestRideRoute,
    this.topSpeedKmh = 0,
    this.topSpeedDate,
    this.climbM = 0,
    this.maxLeanDeg,
    this.dayKm = const [],
    this.weekdayRides = const [0, 0, 0, 0, 0, 0, 0],
    this.hourRides = const [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ],
  });

  /// Days with at least one ride.
  int get activeDays => dayKm.where((k) => k > 0).length;

  /// The most days ridden in a row.
  int get longestStreakDays {
    var best = 0, run = 0;
    for (final k in dayKm) {
      run = k > 0 ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  /// The weekday (DateTime.monday..sunday) with the most rides; the earlier
  /// day wins a tie. Null without rides.
  int? get favouriteWeekday {
    final i = _peak(weekdayRides);
    return i == null ? null : i + 1;
  }

  /// The starting hour (0-23) with the most rides; null without rides.
  int? get peakHour => _peak(hourRides);

  /// What kind of rider the clock says this is, and the share of rides
  /// behind it (0-1). Null without rides.
  (RiderClock, double)? get riderClock {
    if (rideCount == 0) return null;
    double share(Iterable<int> hours) =>
        hours.fold<int>(0, (a, h) => a + hourRides[h]) / rideCount;
    final night = share([20, 21, 22, 23, 0, 1, 2, 3]);
    final early = share([4, 5, 6, 7]);
    final sunset = share([16, 17, 18, 19]);
    if (night >= 0.25) return (RiderClock.nightOwl, night);
    if (early >= 0.2) return (RiderClock.earlyBird, early);
    if (sunset >= 0.3) return (RiderClock.sunsetChaser, sunset);
    return (RiderClock.daylight, 1 - night - early - sunset);
  }

  static int? _peak(List<int> counts) {
    int? best;
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] > 0 && (best == null || counts[i] > counts[best])) best = i;
    }
    return best;
  }

  /// Below this, a percentage change is noise ("+4300%"), so none is shown.
  static const double minComparableKm = 50;

  /// Distance change against [previousKm] as a fraction (0.25 = +25%); null
  /// when there is nothing worth comparing against.
  double? get changeVsPrevious =>
      previousKm == null || previousKm! < minComparableKm
          ? null
          : (distanceKm - previousKm!) / previousKm!;
}

/// The time of day a rider mostly rides, for the year-in-review story.
/// Night 20:00-03:59, early 04:00-07:59, sunset 16:00-19:59, daylight the rest.
enum RiderClock { earlyBird, daylight, sunsetChaser, nightOwl }

/// The pages of the year-in-review story, in playing order. The enum name is
/// also the coarse analytics value logged when one is shared.
enum StorySlide {
  cover,
  distance,
  days,
  time,
  month,
  weekday,
  clock,
  longest,
  topSpeed,
  climb,
  lean,
  bike,
  growth,
  summary,
}

/// The slides worth showing for [r]: a page whose figure would be empty,
/// trivial or unflattering is left out. [hasBikeName] is false when the
/// favourite bike was deleted, so it has no name to show.
List<StorySlide> storySlides(YearInReview r, {required bool hasBikeName}) {
  final few = r.rideCount < 3; // too few rides for a pattern to mean anything
  final change = r.changeVsPrevious;
  return [
    StorySlide.cover,
    StorySlide.distance,
    StorySlide.days,
    if (r.rideSeconds >= 600) StorySlide.time,
    if (r.busiestMonth != null && !few) StorySlide.month,
    if (!few) StorySlide.weekday,
    if (!few) StorySlide.clock,
    if (r.rideCount >= 2 && r.longestRideKm > 0) StorySlide.longest,
    if (r.topSpeedKmh >= 10) StorySlide.topSpeed,
    if (r.climbM >= 100) StorySlide.climb,
    if ((r.maxLeanDeg ?? 0) >= 10) StorySlide.lean,
    if (hasBikeName && r.favouriteBikeRides > 0) StorySlide.bike,
    if (change != null && change >= 0.05) StorySlide.growth,
    StorySlide.summary,
  ];
}

/// The year a Rides-tab banner should invite the rider to review: the
/// current year in December, last year in January, otherwise null.
int? reviewSeasonYear(DateTime now) => switch (now.month) {
      12 => now.year,
      1 => now.year - 1,
      _ => null,
    };

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
  final jan1 = DateTime.utc(year);
  // UTC day arithmetic: a local-time difference is off by an hour across DST.
  final dayKm =
      List<double>.filled(DateTime.utc(year + 1).difference(jan1).inDays, 0);
  final weekdayRides = List<int>.filled(7, 0);
  final hourRides = List<int>.filled(24, 0);
  RideEntity? longest, fastest;
  var climbM = 0.0;
  double? leanDeg;
  for (final r in inYear) {
    distanceKm += r.distanceKm;
    if (r.distanceKm > longestKm) {
      longestKm = r.distanceKm;
      longest = r;
    }
    if (r.maxSpeedKmh > (fastest?.maxSpeedKmh ?? 0)) fastest = r;
    climbM += r.elevationGainM ?? 0;
    final lean = r.maxLeanDeg;
    if (lean != null && lean > (leanDeg ?? 0)) leanDeg = lean;
    final s = r.startTime;
    dayKm[DateTime.utc(year, s.month, s.day).difference(jan1).inDays] +=
        r.distanceKm;
    weekdayRides[s.weekday - 1]++;
    hourRides[s.hour]++;
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
    favouriteBikeRides: favourite == null ? 0 : countByBike[favourite]!,
    rideSeconds: seconds,
    monthKm: monthKm,
    busiestMonth: busiest == null ? null : busiest + 1,
    previousKm: before.isEmpty
        ? null
        : before.fold<double>(0, (a, r) => a + r.distanceKm),
    inProgress: year == now.year,
    longestRideDate: longest?.startTime,
    longestRideRoute: longest?.routeName,
    topSpeedKmh: fastest?.maxSpeedKmh ?? 0,
    topSpeedDate: fastest?.startTime,
    climbM: climbM,
    maxLeanDeg: leanDeg,
    dayKm: dayKm,
    weekdayRides: weekdayRides,
    hourRides: hourRides,
  );
}
