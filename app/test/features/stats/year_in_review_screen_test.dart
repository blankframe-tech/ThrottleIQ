import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
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
        {Locale locale = const Locale('en'),
        List<BikeEntity> bikes = const []}) =>
    ProviderScope(
      overrides: [
        riderStatsProvider.overrideWith((ref) => load()),
        allBikesProvider.overrideWith((ref) async => bikes),
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

  testWidgets('shows ride time, busiest month and the change on last year',
      (tester) async {
    await tester.pumpWidget(_harness(() async => _stats(all: [
          _ride(DateTime(2024, 4, 1), 100),
          _ride(DateTime(2025, 3, 1), 50),
          _ride(DateTime(2025, 3, 8), 50),
          _ride(DateTime(2025, 9, 1), 25),
        ])));
    await tester.pumpAndSettle();
    expect(find.text('1.5 h'), findsOneWidget); // 3 rides × 30 min
    expect(find.text('March'), findsOneWidget);
    expect(find.text('+25% vs 2024'), findsOneWidget);
  });

  testWidgets('the exported card is square-cornered with fixed colours',
      (tester) async {
    await tester.pumpWidget(
        _harness(() async => _stats(all: [_ride(DateTime(2025, 5, 1), 10)])));
    await tester.pumpAndSettle();
    final card =
        tester.widget<Container>(find.byKey(const Key('year_in_review_card')));
    final deco = card.decoration! as BoxDecoration;
    expect(deco.borderRadius, isNull);
    expect((deco.gradient! as LinearGradient).colors.first,
        AppColorPalette.carbonMonoDark.ink);
  });

  testWidgets('the exported image is always 9:16, phone or iPad',
      (tester) async {
    for (final screen in const [Size(390, 844), Size(1366, 1024)]) {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          _harness(() async => _stats(all: [_ride(DateTime(2025, 5, 1), 10)])));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find
          .ancestor(
              of: find.byKey(const Key('year_in_review_card')),
              matching: find.byType(RepaintBoundary))
          .first);
      expect(boundary.size, const Size(360, 640), reason: '$screen');
    }
  });

  testWidgets('a full Bangla card fits, with logo and store QR',
      (tester) async {
    await tester.pumpWidget(_harness(
        () async => _stats(all: [
              // The current year: the longest ("so far") heading.
              _ride(DateTime(DateTime.now().year - 1, 1, 1), 100),
              _ride(DateTime(DateTime.now().year, 1, 1), 12345.6),
              _ride(DateTime(DateTime.now().year, 1, 2), 25),
            ]),
        locale: const Locale('bn'),
        bikes: [
          BikeEntity(
              createdAt: DateTime(2024),
              id: 'b1',
              userId: 'u1',
              brand: 'Yamaha',
              model: 'FZS V3 Fi Deluxe Special Edition')
        ]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no overflow in 360x640
    expect(find.text('প্রিয় বাইক'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('the current year says "so far"', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_harness(() async => _stats(all: [
          _ride(DateTime(now.year - 1, 1, 1), 10),
          _ride(DateTime(now.year, 1, 1), 20),
        ])));
    await tester.pumpAndSettle();
    expect(find.text('My ${now.year} so far on two wheels'), findsOneWidget);
    expect(find.text('+100% vs this point in ${now.year - 1}'), findsOneWidget);
  });
}
