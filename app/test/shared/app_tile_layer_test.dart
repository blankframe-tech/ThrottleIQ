import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/shared/widgets/app_tile_layer.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  Future<void> pumpMap(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 300,
          height: 300,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(23.8103, 90.4125),
              initialZoom: 12,
            ),
            children: [AppTileLayer()],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Tile requests go through Dio, which schedules zero-length timers. Tear
  // the map down and let them drain so the test doesn't end with timers
  // pending.
  Future<void> disposeMap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('AppTileLayer', () {
    testWidgets('builds with the default OSM config', (tester) async {
      await pumpMap(tester);

      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      // No --dart-define in tests, so the OSM default must apply.
      expect(
        layer.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      // Screens get a plain provider under `flutter test` (see
      // AppTileLayer._tileProvider); the cached one is what ships.
      expect(AppTileLayer.cachedTileProvider, isA<CachedTileProvider>());
      expect(
        layer.tileProvider.headers['User-Agent'],
        'ThrottleIQ (com.bft.throttleiq; contact@blankframe.com)',
      );

      await disposeMap(tester);
    });

    testWidgets('shows the OSM attribution', (tester) async {
      await pumpMap(tester);

      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      await disposeMap(tester);
    });
  });
}
