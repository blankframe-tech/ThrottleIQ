import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/theme/app_theme_context.dart';
import 'package:throttleiq/features/ride/domain/calculators/speed_segments.dart';
import 'package:throttleiq/features/ride/presentation/speed_band_style.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/shared/widgets/full_screen_route_map_screen.dart';

void main() {
  const route = [
    LatLng(23.80, 90.40),
    LatLng(23.81, 90.41),
    LatLng(23.82, 90.42),
  ];

  Future<List<Color>> pumpLineColors(WidgetTester tester,
      {List<double> speedsMs = const []}) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FullScreenRouteMapScreen(
          polyline: route,
          speedsMs: speedsMs,
          title: 'Ride',
          subtitle: '2.8 km',
          distanceKm: 2.8,
          durationSeconds: 600,
          maxSpeedKmh: 108,
          avgSpeedKmh: 40,
        ),
      ),
    ));
    await tester.pump();
    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    return [for (final line in layer.polylines) line.color];
  }

  testWidgets('colours the route by speed band, like the ride summary',
      (tester) async {
    // 1 m/s idle, 20 m/s (72 km/h) brisk, 30 m/s (108 km/h) hard.
    final colors = await pumpLineColors(tester, speedsMs: [1, 20, 30]);
    final context = tester.element(find.byType(FullScreenRouteMapScreen));
    expect(colors, [
      SpeedBand.idle.color(context),
      SpeedBand.brisk.color(context),
    ]);
  });

  testWidgets('without speeds it draws one primary line', (tester) async {
    final colors = await pumpLineColors(tester);
    final context = tester.element(find.byType(FullScreenRouteMapScreen));
    expect(colors, [context.palette.primary]);
  });
}
