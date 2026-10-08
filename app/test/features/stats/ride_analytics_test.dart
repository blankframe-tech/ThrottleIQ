import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';

RideEntity _ride(
  String id,
  DateTime start, {
  double km = 10,
  double? avgKmh = 30,
  double? maxKmh = 60,
  int? duration = 1200,
  int? moving = 900,
  int brakes = 0,
  int accel = 0,
  int jerk = 0,
  int? overspeed,
  String bike = 'b1',
}) =>
    RideEntity(
      id: id,
      userId: 'u',
      bikeId: bike,
      startTime: start,
      distanceM: km * 1000,
      avgSpeedMs: avgKmh == null ? null : avgKmh / 3.6,
      maxSpeedMs: maxKmh == null ? null : maxKmh / 3.6,
      durationSeconds: duration,
      movingSeconds: moving,
      hardBrakeCount: brakes,
      rapidAccelCount: accel,
      highJerkCount: jerk,
      overspeedCount: overspeed,
      status: RideStatus.completed,
    );

void main() {
  // Friday 9 Oct 2026, mid-afternoon.
  final now = DateTime(2026, 10, 9, 15);

  group('MetricSummary', () {
    test('computes min/max/avg/total', () {
      final s = MetricSummary.of([2, 8, 5]);
      expect(s.min, 2);
      expect(s.max, 8);
      expect(s.avg, 5);
      expect(s.total, 15);
      expect(s.count, 3);
      expect(s.aggregate(Aggregation.sum), 15);
      expect(s.aggregate(Aggregation.mean), 5);
    });

    test('empty input is the empty summary', () {
      expect(MetricSummary.of(const []).isEmpty, isTrue);
    });
  });

  group('perRideSeries', () {
    test('is chronological regardless of input order', () {
      final rides = [
        _ride('b', DateTime(2026, 10, 2), km: 20),
        _ride('a', DateTime(2026, 10, 1), km: 5),
      ];
      final s = perRideSeries(AnalyticsChart.distancePerRide, rides);
      expect(s.map((p) => p.key), ['a', 'b']);
      expect(s.map((p) => p.value), [5, 20]);
    });

    test('skips rides that do not carry the metric', () {
      final rides = [
        _ride('legacy', DateTime(2026, 10, 1), moving: null),
        _ride('new', DateTime(2026, 10, 2), duration: 600, moving: 450),
      ];
      final jam = perRideSeries(AnalyticsChart.jamTime, rides);
      expect(jam.single.key, 'new');
      expect(jam.single.value, closeTo(2.5, 1e-9)); // 150 s
      final share = perRideSeries(AnalyticsChart.movingVsStopped, rides);
      expect(share.single.value, closeTo(75, 1e-9));
      expect(share.single.secondary, closeTo(2.5, 1e-9));
    });

    test('speed charts skip rides with no recorded speed', () {
      final rides = [_ride('x', DateTime(2026, 10, 1), avgKmh: null)];
      expect(perRideSeries(AnalyticsChart.avgSpeed, rides), isEmpty);
    });

    test('score uses the shared riding score', () {
      final r = _ride('x', DateTime(2026, 10, 1), brakes: 2, accel: 1, jerk: 3);
      // 100 - (2*5 + 1*3 + 3*1) = 84
      expect(perRideValue(AnalyticsChart.ridingScore, r), 84);
      expect(perRideValue(AnalyticsChart.hardBraking, r), 2);
      expect(perRideValue(AnalyticsChart.rapidAccel, r), 1);
      expect(perRideValue(AnalyticsChart.rideDuration, r), 20);
    });

    test('moving share clamps when moving exceeds duration', () {
      final r = _ride('x', DateTime(2026, 10, 1), duration: 100, moving: 130);
      expect(movingSharePercent(r), 100);
      expect(movingStoppedMinutes(r)!.stoppedMin, 0);
    });
  });

  group('overspeed', () {
    test('skips legacy rides with no count; zero is a real value', () {
      final rides = [
        _ride('legacy', DateTime(2026, 10, 1)),
        _ride('clean', DateTime(2026, 10, 2), overspeed: 0),
        _ride('fast', DateTime(2026, 10, 3), overspeed: 3),
      ];
      final s = perRideSeries(AnalyticsChart.overspeed, rides);
      expect(s.map((p) => p.key), ['clean', 'fast']);
      expect(s.map((p) => p.value), [0, 3]);
      expect(periodAggregate(AnalyticsChart.overspeed, rides), 3);
      final i = buildInsights(AnalyticsChart.overspeed, rides, s, now: now);
      expect(i.single.kind, InsightKind.cleanRides);
      expect(i.single.value, 1);
      expect(i.single.value2, 2);
    });

    test('all-legacy history has no overspeed data', () {
      final rides = [_ride('legacy', DateTime(2026, 10, 1))];
      expect(perRideSeries(AnalyticsChart.overspeed, rides), isEmpty);
      expect(periodAggregate(AnalyticsChart.overspeed, rides), isNull);
    });
  });

  group('calendar metrics', () {
    test('weekStartOf is the Monday of the week', () {
      expect(weekStartOf(DateTime(2026, 10, 9, 23)), DateTime(2026, 10, 5));
      expect(weekStartOf(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
      expect(weekStartOf(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
    });

    test('weeklyDistance fills empty weeks', () {
      final rides = [
        _ride('a', DateTime(2026, 9, 22), km: 10), // week of 21 Sep
        _ride('b', DateTime(2026, 9, 24), km: 5), // week of 21 Sep
        _ride('c', DateTime(2026, 10, 6), km: 7), // week of 5 Oct
      ];
      final w = weeklyDistance(rides, now: now, weeks: 4);
      expect(w.map((p) => p.date), [
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
      ]);
      expect(w.map((p) => p.value), [0, 15, 0, 7]);
      // Unbounded: starts at the first ride's week.
      expect(weeklyDistance(rides, now: now).length, 3);
    });

    test('dailyDistance includes zero days and counts rides', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 7, 8), km: 3),
        _ride('b', DateTime(2026, 10, 7, 18), km: 4),
      ];
      final d = dailyDistance(rides,
          from: DateTime(2026, 10, 6), to: DateTime(2026, 10, 8));
      expect(d.map((p) => p.value), [0, 7, 0]);
      expect(d[1].secondary, 2);
    });

    test('ridingStreaks counts current (through yesterday) and longest', () {
      final rides = [
        _ride('1', DateTime(2026, 9, 1)),
        _ride('2', DateTime(2026, 9, 2)),
        _ride('3', DateTime(2026, 9, 3)),
        _ride('4', DateTime(2026, 9, 4)),
        _ride('5', DateTime(2026, 10, 7)),
        _ride('6', DateTime(2026, 10, 8, 9)),
        _ride('6b', DateTime(2026, 10, 8, 19)), // same day twice
      ];
      final s = ridingStreaks(rides, now: now);
      expect(s.longest, 4);
      expect(s.current, 2); // 7 + 8 Oct; today not ridden yet
      final broken = ridingStreaks(rides, now: DateTime(2026, 10, 12));
      expect(broken.current, 0);
      expect(ridingStreaks(const [], now: now), (current: 0, longest: 0));
    });

    test('ridesByHour and ridesByWeekday bucket start times', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 5, 8), km: 2), // Monday
        _ride('b', DateTime(2026, 10, 6, 8), km: 3), // Tuesday
        _ride('c', DateTime(2026, 10, 11, 21), km: 4), // Sunday
      ];
      final h = ridesByHour(rides);
      expect(h.length, 24);
      expect(h[8].value, 2);
      expect(h[8].secondary, 5);
      expect(h[21].value, 1);
      final d = ridesByWeekday(rides);
      expect(d.length, 7);
      expect(d.map((p) => p.value), [1, 1, 0, 0, 0, 0, 1]);
      expect(d.last.bucket, DateTime.sunday);
    });

    test('distanceByBike sorts by distance and counts rides', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 1), km: 5, bike: 'x'),
        _ride('b', DateTime(2026, 10, 2), km: 20, bike: 'y'),
        _ride('c', DateTime(2026, 10, 3), km: 6, bike: 'x'),
      ];
      final b = distanceByBike(rides);
      expect(b.map((p) => p.key), ['y', 'x']);
      expect(b.map((p) => p.value), [20, 11]);
      expect(b[1].secondary, 2);
    });

    test('longestRides takes the top N by distance', () {
      final rides = [
        for (var i = 1; i <= 7; i++)
          _ride('r$i', DateTime(2026, 10, i), km: i * 1.0),
      ];
      final l = longestRides(rides, limit: 3);
      expect(l.map((p) => p.key), ['r7', 'r6', 'r5']);
    });
  });

  group('ranges and trends', () {
    test('rangeWindow covers today and the previous N-1 days', () {
      final w = rangeWindow(AnalyticsRange.days7, now)!;
      expect(w.start, DateTime(2026, 10, 3));
      expect(w.end, DateTime(2026, 10, 10));
      final p = previousRangeWindow(AnalyticsRange.days7, now)!;
      expect(p.start, DateTime(2026, 9, 26));
      expect(p.end, DateTime(2026, 10, 3));
      expect(rangeWindow(AnalyticsRange.all, now), isNull);
      expect(previousRangeWindow(AnalyticsRange.all, now), isNull);
    });

    test('ridesInRange filters by start time', () {
      final rides = [
        _ride('old', DateTime(2026, 9, 1)),
        _ride('in', DateTime(2026, 10, 4)),
      ];
      expect(ridesInRange(rides, AnalyticsRange.days7, now).map((r) => r.id),
          ['in']);
      expect(ridesInRange(rides, AnalyticsRange.all, now).length, 2);
    });

    test('trendPercent', () {
      expect(trendPercent(150, 100), 50);
      expect(trendPercent(50, 100), -50);
      expect(trendPercent(10, 0), isNull);
      expect(trendPercent(null, 10), isNull);
      expect(trendPercent(10, null), isNull);
    });

    test('periodAggregate sums additive metrics and averages rates', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 1), km: 10, avgKmh: 20),
        _ride('b', DateTime(2026, 10, 2), km: 30, avgKmh: 40),
      ];
      expect(periodAggregate(AnalyticsChart.distancePerRide, rides), 40);
      expect(
          periodAggregate(AnalyticsChart.avgSpeed, rides), closeTo(30, 1e-9));
      expect(periodAggregate(AnalyticsChart.hourOfDay, rides), 2);
      expect(periodAggregate(AnalyticsChart.longestRides, rides), 30);
      expect(periodAggregate(AnalyticsChart.distancePerRide, const []), isNull);
    });

    test('buildSeries bounds calendar charts by the window', () {
      final rides = [_ride('a', DateTime(2026, 10, 8))];
      final w = rangeWindow(AnalyticsRange.days7, now);
      final days = buildSeries(AnalyticsChart.activityCalendar, rides,
          now: now, window: w);
      expect(days.length, 7);
      expect(days.last.date, DateTime(2026, 10, 9));
      final weeks = buildSeries(AnalyticsChart.weeklyDistance, rides,
          now: now, window: rangeWindow(AnalyticsRange.days30, now));
      expect(weeks.last.date, DateTime(2026, 10, 5));
      expect(weeks.first.date, weekStartOf(DateTime(2026, 9, 10)));
    });
  });

  group('buildPreviewSeries', () {
    test('per-ride charts keep the last 20 rides', () {
      final rides = [
        for (var i = 0; i < 30; i++)
          _ride('r$i', DateTime(2026, 9, 1).add(Duration(days: i)), km: i + 1),
      ];
      final s =
          buildPreviewSeries(AnalyticsChart.distancePerRide, rides, now: now);
      expect(s.length, previewRideCount);
      expect(s.first.key, 'r10');
      expect(s.last.key, 'r29');
    });

    test('calendar charts cover the last 12 weeks', () {
      final rides = [_ride('a', DateTime(2026, 10, 8))];
      final weeks =
          buildPreviewSeries(AnalyticsChart.weeklyDistance, rides, now: now);
      expect(weeks.length, previewWeekCount);
      final days =
          buildPreviewSeries(AnalyticsChart.activityCalendar, rides, now: now);
      expect(days.first.date!.weekday, DateTime.monday);
      expect(days.last.date, DateTime(2026, 10, 9));
      expect(days.length, 7 * 11 + 5); // 11 full weeks + Mon..Fri
    });
  });

  group('buildInsights', () {
    test('no data', () {
      final i = buildInsights(
          AnalyticsChart.distancePerRide, const [], const [],
          now: now);
      expect(i.single.kind, InsightKind.notEnoughData);
    });

    test('peak value plus trend', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 1), km: 10),
        _ride('b', DateTime(2026, 10, 2), km: 30),
      ];
      final s = perRideSeries(AnalyticsChart.distancePerRide, rides);
      final i = buildInsights(AnalyticsChart.distancePerRide, rides, s,
          now: now, trend: -20);
      expect(i[0].kind, InsightKind.peakValue);
      expect(i[0].value, 30);
      expect(i[0].date, DateTime(2026, 10, 2));
      expect(i[1].kind, InsightKind.trendDown);
      expect(i[1].value, 20);
      final flat = buildInsights(AnalyticsChart.distancePerRide, rides, s,
          now: now, trend: 1);
      expect(flat[1].kind, InsightKind.trendFlat);
    });

    test('clean rides for harsh events', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 1), brakes: 0),
        _ride('b', DateTime(2026, 10, 2), brakes: 3),
      ];
      final s = perRideSeries(AnalyticsChart.hardBraking, rides);
      final i = buildInsights(AnalyticsChart.hardBraking, rides, s, now: now);
      expect(i.single.kind, InsightKind.cleanRides);
      expect(i.single.value, 1);
      expect(i.single.value2, 2);
    });

    test('stopped share over the whole period', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 1), duration: 1000, moving: 750),
        _ride('b', DateTime(2026, 10, 2), duration: 1000, moving: 1000),
      ];
      final s = perRideSeries(AnalyticsChart.jamTime, rides);
      final i = buildInsights(AnalyticsChart.jamTime, rides, s, now: now);
      expect(i.single.kind, InsightKind.stoppedShare);
      expect(i.single.value, closeTo(12.5, 1e-9));
    });

    test('peak hour, top bike, streak', () {
      final rides = [
        _ride('a', DateTime(2026, 10, 8, 18), km: 30, bike: 'x'),
        _ride('b', DateTime(2026, 10, 9, 18), km: 10, bike: 'y'),
        _ride('c', DateTime(2026, 10, 9, 7), km: 10, bike: 'x'),
      ];
      final hour = buildInsights(
          AnalyticsChart.hourOfDay, rides, ridesByHour(rides),
          now: now);
      expect(hour.single.kind, InsightKind.peakHour);
      expect(hour.single.value, 18);
      final bike = buildInsights(
          AnalyticsChart.distanceByBike, rides, distanceByBike(rides),
          now: now);
      expect(bike.single.key, 'x');
      expect(bike.single.value, closeTo(80, 1e-9));
      final streak = buildInsights(AnalyticsChart.activityCalendar, rides,
          dailyDistance(rides, from: DateTime(2026, 10, 8), to: now),
          now: now);
      expect(streak.single.kind, InsightKind.streak);
      expect(streak.single.value, 2);
    });
  });

  group('toCsv', () {
    test('escapes commas, quotes and newlines', () {
      final csv = toCsv(
        ['date', 'bike'],
        [
          ['2026-10-01', 'Honda, CB'],
          ['2026-10-02', 'The "Beast"'],
          ['2026-10-03', 'two\nlines'],
          ['2026-10-04', null],
        ],
      );
      expect(
        csv,
        'date,bike\r\n'
        '2026-10-01,"Honda, CB"\r\n'
        '2026-10-02,"The ""Beast"""\r\n'
        '2026-10-03,"two\nlines"\r\n'
        '2026-10-04,\r\n',
      );
    });
  });
}
