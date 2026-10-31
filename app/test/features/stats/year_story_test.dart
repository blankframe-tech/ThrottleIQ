import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/year_in_review.dart';
import 'package:throttleiq/features/stats/presentation/providers/rider_stats_provider.dart';
import 'package:throttleiq/features/stats/presentation/screens/year_in_review_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

import '../../key_screens.dart';

/// A year that fills every page of the story, plus a smaller year before it.
final _rides = [
  RideEntity(
      id: 'old',
      userId: 'u1',
      bikeId: 'b1',
      startTime: DateTime(2025, 6, 1),
      distanceM: 900000),
  for (var i = 0; i < 40; i++)
    RideEntity(
      id: 'r$i',
      userId: 'u1',
      bikeId: 'b1',
      startTime: DateTime(2026, 1 + i % 10, 1 + i, (i * 5) % 24),
      distanceM: 25000.0 + i * 1500,
      durationSeconds: 3000 + i * 60,
      avgSpeedMs: 9,
      maxSpeedMs: 22 + i * 0.2,
      elevationGainM: 120,
      maxLeanDeg: 31,
      routeName:
          i == 39 ? 'Dhaka to Sylhet via the long and winding hill road' : null,
    ),
];

Widget _app({Locale locale = const Locale('en')}) => ProviderScope(
      overrides: [
        riderStatsProvider.overrideWith((ref) async => RiderStatsSummary(
              allTimeAvgSpeedKmh: 0,
              allTimeTopSpeedKmh: 0,
              avgRidingScore: 0,
              mostUsedBike: null,
              totalRides: _rides.length,
              totalDistanceKm: 0,
              recentRides: const [],
              allRides: _rides,
            )),
        allBikesProvider.overrideWith((ref) async => [
              BikeEntity(
                  createdAt: DateTime(2024),
                  id: 'b1',
                  userId: 'u1',
                  brand: 'Yamaha',
                  model: 'FZS V3 Fi Deluxe Special Edition'),
            ]),
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
        home: const YearInReviewScreen(initialYear: 2026, music: false),
      ),
    );

/// The summary page is the year card, which keeps its own key.
Finder _page(StorySlide s) => find.byKey(Key(
    s == StorySlide.summary ? 'year_in_review_card' : 'year_story_${s.name}'));

/// Real time passing: many frames, as a ticker only moves on frames.
Future<void> _wait(WidgetTester tester, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets the data load and the first page start, without running the story.
Future<void> _open(WidgetTester tester,
    {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(_app(locale: locale));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadKeyScreenFonts);

  testWidgets('pages advance by themselves every five seconds', (tester) async {
    await _open(tester);
    expect(_page(StorySlide.cover), findsOneWidget);
    await _wait(tester, const Duration(seconds: 4));
    expect(_page(StorySlide.cover), findsOneWidget);
    await _wait(tester, const Duration(milliseconds: 1200));
    expect(_page(StorySlide.distance), findsOneWidget);
  });

  testWidgets('tap right for next, left for previous', (tester) async {
    await _open(tester);
    final area = tester.getRect(_page(StorySlide.cover));
    await tester.tapAt(area.centerRight - const Offset(20, 0));
    await tester.pump();
    expect(_page(StorySlide.distance), findsOneWidget);
    await tester.tapAt(area.centerLeft + const Offset(20, 0));
    await tester.pump();
    expect(_page(StorySlide.cover), findsOneWidget);
  });

  testWidgets('holding a page pauses the story', (tester) async {
    await _open(tester);
    final gesture =
        await tester.startGesture(tester.getCenter(_page(StorySlide.cover)));
    await tester.pump(const Duration(seconds: 1)); // long-press kicks in
    await _wait(tester, const Duration(seconds: 8));
    expect(_page(StorySlide.cover), findsOneWidget);
    await gesture.up();
    await _wait(tester, const Duration(seconds: 6));
    expect(_page(StorySlide.distance), findsOneWidget);
  });

  testWidgets('with a screen reader, pages wait to be turned', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester);
    await _wait(tester, const Duration(seconds: 12));
    expect(_page(StorySlide.cover), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(_page(StorySlide.distance), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('every page fits its 360x640 canvas ($locale)', (tester) async {
      await _open(tester, locale: locale);
      final seen = <StorySlide>[];
      for (final s in StorySlide.values) {
        await _wait(tester, const Duration(seconds: 2)); // entrance finished
        expect(_page(s), findsOneWidget, reason: '$s after $seen');
        expect(tester.takeException(), isNull, reason: '$s overflowed');
        final boundary = tester.renderObject<RenderRepaintBoundary>(find
            .ancestor(of: _page(s), matching: find.byType(RepaintBoundary))
            .first);
        expect(boundary.size, const Size(360, 640), reason: '$s');
        seen.add(s);
        if (s != StorySlide.summary) {
          await tester.tap(find.byTooltip(
              locale.languageCode == 'en' ? 'Next page' : 'পরের পাতা'));
          await tester.pump();
        }
      }
      expect(seen, StorySlide.values);
    });
  }

  testWidgets('the last page rests and offers a replay', (tester) async {
    await _open(tester);
    await _wait(tester, const Duration(seconds: 90));
    expect(_page(StorySlide.summary), findsOneWidget);
    await _wait(tester, const Duration(seconds: 10));
    expect(_page(StorySlide.summary), findsOneWidget); // rests, no loop
    await tester.tap(find.byKey(const Key('year_story_replay')));
    await tester.pump();
    expect(_page(StorySlide.cover), findsOneWidget);
  });

  testWidgets('the figures are real: distance, persona, bike', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Next page'));
    await _wait(tester, const Duration(seconds: 2));
    // 40 rides of 25 + 1.5i km = 2,170 km.
    expect(find.text('2,170 km'), findsOneWidget);
    expect(find.text('Dhaka to Cox\'s Bazar, 5.4× over'), findsOneWidget);
    while (find.byKey(const Key('year_story_bike')).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Next page'));
      await _wait(tester, const Duration(seconds: 2));
    }
    expect(
        find.text('Yamaha FZS V3 Fi Deluxe Special Edition'), findsOneWidget);
    expect(find.text('40 of my 40 rides'), findsOneWidget);
  });
}
