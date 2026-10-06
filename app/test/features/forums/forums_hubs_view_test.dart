import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';
import 'package:throttleiq/features/forums/presentation/providers/forum_providers.dart';
import 'package:throttleiq/features/forums/presentation/screens/forums_home_screen.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _Garage extends GarageNotifier {
  _Garage(this._bikes);
  final List<BikeEntity> _bikes;
  @override
  Future<List<BikeEntity>> build() async => _bikes;
}

void main() {
  var searched = 0;
  final bike = BikeEntity(
    id: 'b1',
    userId: 'u',
    brand: 'Yamaha',
    model: 'MT-15',
    year: 2023,
    odometerKm: 12400,
    isActive: true,
    createdAt: DateTime(2026),
  );
  final garageForum = ForumEntity(
    id: 'yamaha__mt_15',
    type: ForumType.bikeModel,
    brand: 'Yamaha',
    model: 'MT-15',
    displayName: 'Yamaha MT-15',
    postCount: 7,
    createdAt: DateTime(2026),
  );

  Future<void> pumpHubs(WidgetTester tester, {List<ForumEntity>? garageForums}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    searched = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          garageProvider.overrideWith(() => _Garage([bike])),
          forumsForGarageProvider.overrideWith((ref) async => garageForums ?? [garageForum]),
          forumFollowingProvider.overrideWith((ref, id) async => false),
          customForumsProvider.overrideWith((ref) async => const <ForumEntity>[]),
          directoryForumStatsProvider.overrideWith((ref) async => {
                'yamaha': ForumEntity(
                  id: 'yamaha',
                  type: ForumType.brand,
                  brand: 'Yamaha',
                  displayName: 'Yamaha',
                  followerCount: 42,
                  createdAt: DateTime(2026),
                ),
              }),
          forumsPulseFeedProvider.overrideWith((ref) async => const PulseFirstPage(
                sources: PulseSources.empty,
                page: ForumPostsPage(posts: [], cursor: null, hasMore: false),
              )),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ForumsHomeScreen(onOpenSearch: () => searched++)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hubs'));
    await tester.pumpAndSettle();
  }

  testWidgets('Hubs shows the garage hero, brand paddocks and topic bento', (tester) async {
    await pumpHubs(tester);

    expect(find.byKey(const Key('garage_hub_yamaha__mt_15')), findsOneWidget);
    expect(find.text('Yamaha MT-15 (2023)'), findsOneWidget);
    expect(find.textContaining('12,400 km'), findsOneWidget);
    expect(find.textContaining('7 threads'), findsOneWidget);
    expect(find.text('Ask owners'), findsOneWidget);

    expect(find.byKey(const Key('paddock_yamaha')), findsOneWidget);
    expect(find.text('42 riders'), findsOneWidget);

    expect(find.text('The Wrench Bench'), findsOneWidget);
    expect(find.text('Apex Lab'), findsOneWidget);

    // No second, in-page forum search box — only the AppBar shortcut.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('hubs_search')));
    expect(searched, 1);
  });

  testWidgets('an empty garage shows the unlock banner', (tester) async {
    await pumpHubs(tester, garageForums: const []);
    expect(find.text('Open Garage'), findsOneWidget);
  });
}
