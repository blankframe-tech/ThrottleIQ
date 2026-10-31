import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/presentation/providers/rider_stats_provider.dart';
import 'package:throttleiq/features/stats/presentation/screens/year_in_review_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

import '../../key_screens.dart';

RideEntity _ride(DateTime start, double km) => RideEntity(
      id: '$start',
      userId: 'u1',
      bikeId: 'b1',
      startTime: start,
      distanceM: km * 1000,
      durationSeconds: 1800,
    );

RiderStatsSummary _stats({
  List<RideEntity> all = const [],
  List<RideEntity> recent = const [],
}) =>
    RiderStatsSummary(
      allTimeAvgSpeedKmh: 0,
      allTimeTopSpeedKmh: 0,
      avgRidingScore: 0,
      mostUsedBike: null,
      totalRides: all.length,
      totalDistanceKm: 0,
      recentRides: recent,
      allRides: all,
    );

Widget _harness(Future<RiderStatsSummary> Function() load,
        {Locale locale = const Locale('en')}) =>
    ProviderScope(
      overrides: [
        riderStatsProvider.overrideWith((ref) => load()),
        allBikesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const YearInReviewScreen(),
      ),
    );

void main() {
  setUpAll(loadKeyScreenFonts);

  testWidgets('a spinner, not "No rides yet.", while loading', (tester) async {
    final pending = Completer<RiderStatsSummary>();
    await tester.pumpWidget(_harness(() => pending.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No rides yet.'), findsNothing);
  });

  testWidgets('a load error offers a retry instead of "No rides yet."',
      (tester) async {
    await tester.pumpWidget(_harness(() async => throw StateError('offline')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your rides."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No rides yet.'), findsNothing);
  });

  testWidgets('an old cached summary falls back to recent rides',
      (tester) async {
    await tester.pumpWidget(_harness(
        () async => _stats(recent: [_ride(DateTime(2025, 5, 1), 42)])));
    await tester.pumpAndSettle();
    expect(find.text('No rides yet.'), findsNothing);
    expect(find.textContaining('2025'), findsWidgets);
  });

  testWidgets('distances are grouped and share one format', (tester) async {
    await tester.pumpWidget(_harness(() async => _stats(all: [
          _ride(DateTime(2025, 5, 1), 12000),
          _ride(DateTime(2025, 6, 1), 345.6),
        ])));
    await tester.pumpAndSettle();
    expect(find.text('12,345.6 km'), findsOneWidget);
    expect(find.text('12,000 km'), findsOneWidget);
  });

  testWidgets('Bangla: translated unit, labels not uppercased', (tester) async {
    await tester.pumpWidget(_harness(
        () async => _stats(all: [_ride(DateTime(2025, 5, 1), 1234)]),
        locale: const Locale('bn')));
    await tester.pumpAndSettle();
    expect(find.text('1,234 কিমি'), findsWidgets);
    expect(find.textContaining(' km'), findsNothing);
    expect(find.text('মোট দূরত্ব'), findsOneWidget);
  });

  testWidgets('a deleted favourite bike leaves its row off the card',
      (tester) async {
    await tester.pumpWidget(
        _harness(() async => _stats(all: [_ride(DateTime(2025, 5, 1), 10)])));
    await tester.pumpAndSettle();
    expect(find.text('Favourite bike'), findsNothing);
    expect(find.text('Unknown bike'), findsNothing);
  });
}
