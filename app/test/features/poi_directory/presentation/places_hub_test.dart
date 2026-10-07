import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/poi_directory/data/repositories/saved_places_repository.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/domain/place_tags.dart';
import 'package:throttleiq/features/poi_directory/domain/places_query.dart';
import 'package:throttleiq/features/poi_directory/presentation/place_category_style.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_provider.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_search_provider.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/saved_places_provider.dart';
import 'package:throttleiq/features/poi_directory/presentation/screens/places_list_screen.dart';
import 'package:throttleiq/features/poi_directory/presentation/widgets/places_map_view.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

const _lat = 23.7580;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Sport/dark: the lime primary that white text failed on (issues §101.P1).
final _sportDark = AppTheme.build(const AppAppearance(
  colorMode: AppColorMode.sport,
  shapeVibe: AppShapeVibe.boxy,
  brightness: Brightness.dark,
));
const _lng = 90.3900;

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'rider-1';
}

/// In-memory stand-in for the SQLite-backed repository (the real one is
/// covered against a real database in test/database/saved_places_test.dart).
class _MemorySavedPlaces extends SavedPlacesRepository {
  final Map<String, List<PlaceEntity>> byUser = {};
  bool failNext = false;

  @override
  Future<List<PlaceEntity>> savedPlaces(String userId) async => [...?byUser[userId]];

  @override
  Future<void> save(String userId, PlaceEntity place, {DateTime? now}) async {
    if (failNext) {
      failNext = false;
      throw StateError('disk full');
    }
    (byUser[userId] ??= []).insert(0, place);
  }

  @override
  Future<void> remove(String userId, String placeId) async {
    byUser[userId]?.removeWhere((p) => p.id == placeId);
  }
}

PlaceEntity _place(
  String id,
  String name,
  PlaceCategory category, {
  double kmNorth = 1,
  String? phone,
  Set<PlaceTag> tags = const {},
  double ratingSum = 0,
  int ratingCount = 0,
  double googleRating = 0,
  int googleRatingCount = 0,
}) =>
    PlaceEntity(
      id: id,
      name: name,
      category: category,
      latitude: _lat + kmNorth * 0.009,
      longitude: _lng,
      geohash: '',
      address: '',
      phone: phone,
      createdBy: 'u',
      createdAt: DateTime(2026),
      tags: tags,
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      googleRating: googleRating,
      googleRatingCount: googleRatingCount,
    );

final _places = [
  _place('meghna', 'Meghna Fuel', PlaceCategory.fuel,
      kmNorth: 1, phone: '+880 1711-000000', tags: {PlaceTag.open24h}),
  _place('moto', 'Central Moto Works', PlaceCategory.garage,
      kmNorth: 3, ratingSum: 24, ratingCount: 5, googleRating: 4.4, googleRatingCount: 110),
  _place('chai', 'Biker Chai', PlaceCategory.recreation, kmNorth: 6),
  _place('cam1', 'Bijoy Sarani camera', PlaceCategory.aiCamera, kmNorth: 2),
  _place('cam2', 'Airport Rd camera', PlaceCategory.aiCamera, kmNorth: 8),
  _place('cop', 'Shahbag checkpost', PlaceCategory.police, kmNorth: 4),
];

final _position = Position(
  latitude: _lat,
  longitude: _lng,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _MemorySavedPlaces saved;
  late List<double> fetchedRadii;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    saved = _MemorySavedPlaces();
    fetchedRadii = [];
  });

  ProviderContainer container({List<PlaceEntity>? places, Object? error}) {
    final c = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(_FakeUser()),
      savedPlacesRepositoryProvider.overrideWithValue(saved),
      currentPositionProvider.overrideWith((ref) async => _position),
      nearbyPlacesProvider.overrideWith((ref, radius) async {
        fetchedRadii.add(radius);
        if (error != null) throw error;
        return places ?? _places;
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> pumpHub(
    WidgetTester tester, {
    PlacesViewMode mode = PlacesViewMode.list,
    Locale locale = const Locale('en'),
    List<PlaceEntity>? places,
    Object? error,
    ThemeData? theme,
  }) async {
    // A tall phone, so all three cards are laid out at once.
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = container(places: places, error: error);
    c.read(placesViewModeProvider.notifier).state = mode;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('bn')],
        locale: locale,
        // The map's pulsing dots honour reduce-motion, which keeps
        // pumpAndSettle from waiting on an endless animation.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const PlacesListScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  group('PlacesQueryNotifier', () {
    test('debounces search text', () async {
      final c = container();
      final n = c.read(placesQueryProvider.notifier);
      n.setTextDebounced('sh');
      n.setTextDebounced('shell');
      expect(c.read(placesQueryProvider).text, '');
      await Future<void>.delayed(placesSearchDebounce + const Duration(milliseconds: 50));
      expect(c.read(placesQueryProvider).text, 'shell');
    });

    test('setText applies at once and cancels a pending debounce', () async {
      final c = container();
      final n = c.read(placesQueryProvider.notifier);
      n.setTextDebounced('stale');
      n.setText('');
      await Future<void>.delayed(placesSearchDebounce + const Duration(milliseconds: 50));
      expect(c.read(placesQueryProvider).text, '');
    });

    test('radius is remembered across sessions', () async {
      final c = container();
      await c.read(placesQueryProvider.notifier).setRadius(50);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(placesRadiusPrefKey), 50);

      final next = container();
      next.read(placesQueryProvider);
      await pumpEventQueue();
      expect(next.read(placesQueryProvider).radiusKm, 50);
    });

    test('toggleTag and clearRefinements', () {
      final c = container();
      final n = c.read(placesQueryProvider.notifier)
        ..toggleTag(PlaceTag.octane95)
        ..toggleTag(PlaceTag.open24h)
        ..toggleTag(PlaceTag.octane95)
        ..setVerifiedOnly(true)
        ..setCategory(PlaceCategory.fuel);
      expect(c.read(placesQueryProvider).tags, {PlaceTag.open24h});
      n.clearRefinements();
      final q = c.read(placesQueryProvider);
      expect(q.tags, isEmpty);
      expect(q.verifiedOnly, isFalse);
      expect(q.category, PlaceCategory.fuel, reason: 'the chip is not a sheet refinement');
    });

    test('the batch is fetched for the selected radius and the radar reads it', () async {
      final c = container();
      await c.read(nearbyPlacesProvider(placesDefaultRadiusKm).future);
      await c.read(currentPositionProvider.future);
      expect(c.read(placesBatchProvider).valueOrNull, hasLength(_places.length));
      final radar = c.read(highwayRadarProvider);
      expect(radar.cameras.length, 2);
      expect(radar.police.length, 1);

      await c.read(placesQueryProvider.notifier).setRadius(5);
      await c.read(nearbyPlacesProvider(5).future);
      expect(fetchedRadii, containsAll([25.0, 5.0]));
      expect(c.read(highwayRadarProvider).total, 2, reason: 'the 8 km camera drops out');
    });
  });

  group('SavedPlacesNotifier', () {
    test('toggle saves, then unsaves', () async {
      final c = container();
      await c.read(savedPlacesProvider.future);
      final n = c.read(savedPlacesProvider.notifier);

      expect(await n.toggle(_places.first), isTrue);
      expect(c.read(savedPlaceIdsProvider), {'meghna'});
      expect(saved.byUser['rider-1'], hasLength(1));

      expect(await n.toggle(_places.first), isFalse);
      expect(c.read(savedPlaceIdsProvider), isEmpty);
      expect(saved.byUser['rider-1'], isEmpty);
    });

    test('a failed write rolls the optimistic state back', () async {
      final c = container();
      await c.read(savedPlacesProvider.future);
      saved.failNext = true;
      await expectLater(c.read(savedPlacesProvider.notifier).toggle(_places.first), throwsStateError);
      await c.read(savedPlacesProvider.future);
      expect(c.read(savedPlaceIdsProvider), isEmpty);
    });
  });

  group('Places hub screen', () {
    testWidgets('list: stops only, with counts, badges and one-tap actions', (tester) async {
      await pumpHub(tester);

      expect(find.text('Meghna Fuel'), findsOneWidget);
      expect(find.text('Central Moto Works'), findsOneWidget);
      expect(find.text('Biker Chai'), findsOneWidget);
      // Cameras and checkposts are radar, not stops.
      expect(find.text('Bijoy Sarani camera'), findsNothing);
      expect(find.text('Shahbag checkpost'), findsNothing);

      // Ribbon: no safety categories, counts per chip.
      expect(find.byKey(const ValueKey('places-chip-aiCamera')), findsNothing);
      expect(find.byKey(const ValueKey('places-chip-police')), findsNothing);
      expect(
        find.descendant(of: find.byKey(const ValueKey('places-chip-all')), matching: find.text('3')),
        findsOneWidget,
      );

      // Clear dual ratings and the Rider Approved badge (4.8 from 5 riders).
      expect(find.text('★ 4.8 (5 riders)'), findsOneWidget);
      expect(find.text('★ 4.4 (110 Google)'), findsOneWidget);
      expect(find.text('Rider Approved'), findsOneWidget);

      // Quick actions on the card: Call only where there's a number.
      expect(find.text('Directions'), findsNWidgets(3));
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Save'), findsNWidgets(3));

      // Routes button is gone; tabs replace it.
      expect(find.text('Browse routes →'), findsNothing);
      expect(find.text('Routes'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('Highway Radar banner summarises cameras and checkposts', (tester) async {
      final c = await pumpHub(tester);
      expect(find.textContaining('Highway Radar: 2 speed cameras · 1 police checkpost'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss radar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Highway Radar'), findsNothing);
      expect(c.read(radarDismissedProvider), isTrue);
    });

    testWidgets('tapping the radar switches to the map and highlights the points', (tester) async {
      final c = await pumpHub(tester);
      await tester.tap(find.textContaining('Highway Radar:'));
      await tester.pumpAndSettle();
      expect(c.read(radarHighlightProvider), isTrue);
      expect(c.read(placesViewModeProvider), PlacesViewMode.map);
      expect(find.byType(PlacesMapView), findsOneWidget);
      expect(find.byKey(const ValueKey('radar-marker-cam1')), findsOneWidget);
      expect(find.byKey(const ValueKey('radar-marker-cop')), findsOneWidget);
    });

    testWidgets('a category chip filters the list', (tester) async {
      await pumpHub(tester);
      await tester.tap(find.byKey(const ValueKey('places-chip-garage')));
      await tester.pumpAndSettle();
      expect(find.text('Central Moto Works'), findsOneWidget);
      expect(find.text('Meghna Fuel'), findsNothing);
    });

    testWidgets('search narrows the list after the debounce', (tester) async {
      await pumpHub(tester);
      await tester.enterText(find.byType(TextField), 'chai');
      await tester.pump(placesSearchDebounce + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('Biker Chai'), findsOneWidget);
      expect(find.text('Meghna Fuel'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nothing like this');
      await tester.pump(placesSearchDebounce + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('No places match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Meghna Fuel'), findsOneWidget);
    });

    testWidgets('Save on a card puts the place in the Saved tab', (tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(saved.byUser['rider-1']!.single.id, 'meghna');

      await tester.tap(find.descendant(
        of: find.byType(SegmentedButton<PlacesHubTab>),
        matching: find.text('Saved'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Places I added'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-meghna')), findsOneWidget);
    });

    testWidgets('map mode shows category pins and the carousel', (tester) async {
      await pumpHub(tester, mode: PlacesViewMode.map);
      expect(find.byType(PlacesMapView), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      // Radar points stay off the map until highlighted.
      expect(find.byKey(const ValueKey('radar-marker-cam1')), findsNothing);
      expect(find.byTooltip('Centre on me'), findsOneWidget);
    });

    for (final locale in const [Locale('en'), Locale('bn')]) {
      for (final mode in PlacesViewMode.values) {
        testWidgets('lays out without overflow on a small phone ($mode, $locale)', (tester) async {
          await pumpHub(tester, mode: mode, locale: locale);
          tester.view.physicalSize = const Size(720, 1480); // 360×740 logical
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('an empty area offers an explained OpenStreetMap scan', (tester) async {
      await pumpHub(tester, places: const []);
      expect(find.text('Nothing mapped here yet'), findsOneWidget);
      expect(find.text('Scan OpenStreetMap'), findsOneWidget);
      expect(find.text('Search 50 km'), findsOneWidget);
    });

    testWidgets('GPS off gets a "Turn on location" fix and a way to saved places', (tester) async {
      await pumpHub(tester,
          error: const PlaceLocationException(PlaceLocationProblem.serviceDisabled));
      expect(find.text('GPS is off'), findsOneWidget);
      expect(find.text('Open saved places'), findsOneWidget);
    });

    testWidgets('offline gets its own card', (tester) async {
      await pumpHub(tester, error: FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Open saved places'));
      await tester.pumpAndSettle();
      expect(find.text('No saved places yet'), findsOneWidget);
    });

    testWidgets('uses ListView.builder for lazy loading', (tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      
      final listView = tester.widget<ListView>(find.byType(ListView).last);
      expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    group('sport/dark contrast (issues §101.P1)', () {
      const palette = AppColorPalette.carbonMonoDark;

      testWidgets('list add-place FAB uses the primary button foreground',
          (tester) async {
        await pumpHub(tester, theme: _sportDark);
        final fab = find.byWidgetPredicate(
            (w) => w is FloatingActionButton && w.heroTag == 'add_place_fab');
        expect(fab, findsOneWidget);
        final expected = AppTheme.primaryButtonForeground(palette);
        final icon = tester.widget<Icon>(
            find.descendant(of: fab, matching: find.byIcon(Icons.add)));
        expect(icon.color, expected);
        final label = tester.widget<Text>(
            find.descendant(of: fab, matching: find.text('Add place')));
        expect(label.style?.color, expected);
        expect(_contrast(expected, palette.primary), greaterThanOrEqualTo(4.5));
      });

      testWidgets('map add FAB uses the primary button foreground',
          (tester) async {
        await pumpHub(tester, mode: PlacesViewMode.map, theme: _sportDark);
        final fab = tester.widget<FloatingActionButton>(find.byWidgetPredicate(
            (w) => w is FloatingActionButton && w.heroTag == 'places_map_add'));
        expect(fab.foregroundColor, AppTheme.primaryButtonForeground(palette));
      });

      testWidgets('cluster count text is readable on the primary bubble',
          (tester) async {
        await pumpHub(
          tester,
          mode: PlacesViewMode.map,
          theme: _sportDark,
          places: [
            _place('a', 'Pump A', PlaceCategory.fuel, kmNorth: 1),
            _place('b', 'Pump B', PlaceCategory.fuel, kmNorth: 1),
          ],
        );
        final count = tester.widget<Text>(find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.text('2'),
        ));
        final expected = AppTheme.primaryButtonForeground(palette);
        expect(count.style?.color, expected);
        expect(_contrast(expected, palette.primary), greaterThanOrEqualTo(4.5));
      });

      testWidgets('a garage pin on the lime accent draws a dark icon',
          (tester) async {
        // Alone, so it is drawn as its own pin rather than in a cluster.
        await pumpHub(tester,
            mode: PlacesViewMode.map,
            theme: _sportDark,
            places: [_places[1]]);
        final icon = tester.widget<Icon>(find.descendant(
          of: find.byKey(const ValueKey('place-marker-moto')),
          matching: find.byIcon(Icons.build),
        ));
        expect(icon.color, markerDarkInk);
        expect(_contrast(icon.color!, palette.primary),
            greaterThanOrEqualTo(3));
      });
    });

    group('markerIconColor', () {
      test('lime accent gets dark ink', () {
        const lime = Color(0xFFC8FF3D);
        expect(markerIconColor(lime), markerDarkInk);
        expect(_contrast(markerIconColor(lime), lime), greaterThanOrEqualTo(3));
      });

      test('danger red gets white', () {
        const red = Color(0xFFC62828);
        expect(markerIconColor(red), Colors.white);
        expect(_contrast(markerIconColor(red), red), greaterThanOrEqualTo(3));
      });

      test('every palette accent meets 3:1', () {
        for (final mode in AppColorMode.values) {
          for (final b in Brightness.values) {
            final p = AppColorPalette.forMode(mode, b);
            for (final accent in [
              p.primary,
              p.secondary,
              p.warning,
              p.success,
              p.danger,
            ]) {
              expect(_contrast(markerIconColor(accent), accent),
                  greaterThanOrEqualTo(3),
                  reason: '${mode.name}/${b.name} $accent');
            }
          }
        }
      });
    });
  });
}
