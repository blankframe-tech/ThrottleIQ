import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/simple/presentation/widgets/simple_rides_week_bars.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

RideEntity _ride(DateTime start, double km) => RideEntity(
      id: '$start',
      userId: 'u1',
      bikeId: 'b1',
      startTime: start,
      status: RideStatus.completed,
      distanceM: km * 1000,
    );

void main() {
  // A Thursday.
  final now = DateTime(2026, 11, 26, 10);
  final rides = [
    _ride(DateTime(2026, 11, 26, 8), 12), // today
    _ride(DateTime(2026, 11, 25, 7), 5), // yesterday, twice
    _ride(DateTime(2026, 11, 25, 22), 3),
    _ride(DateTime(2026, 11, 20, 23, 59), 7), // 6 days ago: oldest bar
    _ride(DateTime(2026, 11, 19, 23, 59), 100), // 7 days ago: outside
    _ride(DateTime(2026, 11, 27, 0, 1), 50), // tomorrow: outside
  ];

  test('buckets km by start day over the last 7 days, oldest first', () {
    expect(simpleRidesKmPerDay(rides, now), [7, 0, 0, 0, 0, 8, 12]);
    expect(simpleRidesKmPerDay(const [], now), List.filled(7, 0));
  });

  test('counts whole calendar days across a month boundary', () {
    final early = DateTime(2026, 12, 2, 0, 30);
    expect(simpleRidesKmPerDay([_ride(DateTime(2026, 11, 26, 23), 4)], early),
        [4, 0, 0, 0, 0, 0, 0]);
  });

  testWidgets('labels the bars for screen readers', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SimpleRidesWeekBars(rides: rides, now: now)),
    ));
    expect(
      find.bySemanticsLabel(
          RegExp(r'Fri 7 km, Sat 0 km.*Wed 8 km, Thu 12 km$')),
      findsOneWidget,
    );
    // Today's bar is the tallest; an empty day still shows a sliver.
    final today = tester.getSize(find.byKey(const Key('simpleRidesBar6')));
    final empty = tester.getSize(find.byKey(const Key('simpleRidesBar1')));
    expect(today.height, greaterThan(empty.height));
    expect(empty.height, greaterThan(0));
  });
}
