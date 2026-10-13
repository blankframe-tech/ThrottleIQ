import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/routes/presentation/providers/navigation_session_provider.dart';
import 'package:throttleiq/features/routes/presentation/widgets/navigation_banner.dart';
import 'package:throttleiq/features/social/domain/entities/route_entity.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The one thing a rider actually looks at while following a route
/// (issues §78.21). §83.28 is the standing complaint that this layer has no
/// coverage; this is the new surface, so it starts with some.
LatLng _offset(LatLng from, double bearingDeg, double metres) {
  const metresPerDegLat = 111320.0;
  final rad = bearingDeg * math.pi / 180.0;
  return LatLng(
    from.latitude + (metres * math.cos(rad)) / metresPerDegLat,
    from.longitude +
        (metres * math.sin(rad)) /
            (metresPerDegLat * math.cos(from.latitude * math.pi / 180.0)),
  );
}

const _dhaka = LatLng(23.8103, 90.4125);

List<LatLng> _straightKm() => [
      _dhaka,
      for (var m = 50.0; m <= 1000.0; m += 50) _offset(_dhaka, 90, m),
    ];

RouteEntity _route() => RouteEntity(
      id: 'route-1',
      userId: 'alice',
      name: 'Mirpur loop',
      distanceKm: 1.0,
      polyline: _straightKm(),
      createdAt: DateTime(2026, 9, 21),
    );

void main() {
  /// Pumps the banner over a session the test drives directly. The provider
  /// is overridden so no `rideRecordingProvider` listener is created — the
  /// folding of recording state into progress has its own tests; this one is
  /// about what ends up on screen.
  Future<NavigationSessionNotifier> pump(
    WidgetTester tester, {
    required void Function(NavigationSessionNotifier) setUp,
  }) async {
    late NavigationSessionNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationSessionProvider.overrideWith((ref) {
            notifier = NavigationSessionNotifier();
            setUp(notifier);
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [
            AppColorPalette.calmingLight,
            AppShapeProfile.curvy,
          ]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: NavigationBanner()),
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  void feed(NavigationSessionNotifier n, LatLng at, {double speedMs = 10}) =>
      n.onRecordingState(RideRecordingState(
        status: RecordingStatus.active,
        currentPosition: at,
        currentSpeedMs: speedMs,
      ));

  testWidgets('draws nothing at all when no route is being followed',
      (tester) async {
    await pump(tester, setUp: (_) {});
    // The cockpit hosts this unconditionally, so "not navigating" has to cost
    // no pixels — not an empty card, not a gap.
    expect(find.byType(Card), findsNothing);
    expect(tester.getSize(find.byType(NavigationBanner)), Size.zero);
  });

  testWidgets('shows the next manoeuvre and how far off it is', (tester) async {
    final n = await pump(tester, setUp: (n) => n.start(_route()));
    feed(n, _offset(_dhaka, 90, 400));
    await tester.pump();

    // ~600 m of route left, at 10 m/s — one minute out. The distance is
    // asserted loosely on purpose: pinning the exact metre would make this a
    // test of the haversine, which navigation_progress_test.dart already
    // covers, and would break on any change to the fixture's geometry.
    expect(find.textContaining(RegExp(r'^59\d m$')), findsOneWidget);
    expect(find.text('1 min'), findsOneWidget);
    expect(find.textContaining('in '), findsOneWidget);
  });

  testWidgets('raises the off-route warning, and drops it on rejoining',
      (tester) async {
    final n = await pump(tester, setUp: (n) => n.start(_route()));

    feed(n, _offset(_offset(_dhaka, 90, 400), 0, 250));
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    feed(n, _offset(_dhaka, 90, 450));
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('says the ride is still recording once the route is done',
      (tester) async {
    final n = await pump(tester, setUp: (n) => n.start(_route()));
    feed(n, _straightKm().last);
    await tester.pump();

    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    // Arriving ends the route, not the ride — and the banner has to say so,
    // or a rider reasonably assumes the recording stopped with the guidance.
    expect(find.textContaining('recording'), findsOneWidget);
  });

  testWidgets('the close button ends guidance without ending the ride',
      (tester) async {
    final n = await pump(tester, setUp: (n) => n.start(_route()));
    feed(n, _offset(_dhaka, 90, 400));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(n.state.isActive, isFalse);
    expect(tester.getSize(find.byType(NavigationBanner)), Size.zero);
    // And it tells the rider the recording carried on, since the banner
    // vanishing is otherwise indistinguishable from the ride ending.
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a route with no usable shape falls back to its name',
      (tester) async {
    final n = await pump(
      tester,
      setUp: (n) => n.start(RouteEntity(
        id: 'r',
        userId: 'alice',
        name: 'Mirpur loop',
        distanceKm: 0,
        polyline: const [_dhaka],
        createdAt: DateTime(2026, 9, 21),
      )),
    );
    // Deliberately not standing on the single point: being within the
    // arrival radius of it would show the arrival line instead, which is its
    // own (correct) behaviour and not what this test is about.
    feed(n, _offset(_dhaka, 90, 500));
    await tester.pump();

    // No instructions to show, so the banner names the route rather than
    // rendering an empty row.
    expect(find.text('Mirpur loop'), findsOneWidget);
  });
}
