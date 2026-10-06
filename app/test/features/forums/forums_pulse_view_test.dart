import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';
import 'package:throttleiq/features/forums/presentation/providers/forum_providers.dart';
import 'package:throttleiq/features/forums/presentation/screens/forums_home_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

ForumPostEntity post(String id, String forum, ForumPostType type, {int up = 0, bool solved = false}) =>
    ForumPostEntity(
      id: id,
      forumId: forum,
      userId: 'u',
      userName: 'Rider $id',
      title: 'Title $id',
      body: 'Body $id',
      createdAt: DateTime(2026, 10, 1),
      postType: type,
      isSolved: solved,
      upvotes: up,
      authorBike: id == 'help' ? 'Yamaha MT-15 · 12,400 km' : null,
    );

void main() {
  final posts = [
    post('help', 'garage', ForumPostType.troubleshoot, up: 2),
    post('diy', 'followed', ForumPostType.diyGuide),
    post('chat', 'followed', ForumPostType.general, up: 4),
  ];
  const sources = PulseSources(
    forumIds: ['garage', 'followed'],
    names: {'garage': 'Yamaha MT-15', 'followed': 'Maintenance'},
    garageForumIds: {'garage'},
  );

  Future<void> pump(WidgetTester tester, {PulseSources s = sources, List<ForumPostEntity>? list}) async {
    SharedPreferences.setMockInitialValues({});
    final shown = list ?? posts;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          forumsPulseFeedProvider.overrideWith((ref) async => PulseFirstPage(
                sources: s,
                page: ForumPostsPage(posts: shown, cursor: null, hasMore: false),
              )),
          pulseFeedNotifierProvider.overrideWith((ref) => ForumPostsNotifier(ref, shown)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ForumsHomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Pulse shows every source post with origin, tag and bike badge', (tester) async {
    await pump(tester);

    expect(find.text('Title help'), findsOneWidget);
    expect(find.text('Title diy'), findsOneWidget);
    expect(find.text('Title chat'), findsOneWidget);
    expect(find.text('Yamaha MT-15'), findsOneWidget); // origin chip
    expect(find.text('HELP NEEDED'), findsOneWidget);
    expect(find.text('GUIDE'), findsOneWidget);
    expect(find.text('Yamaha MT-15 · 12,400 km'), findsOneWidget);
  });

  testWidgets('filter chips narrow the feed without refetching', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('pulse_filter_myBikes')));
    await tester.pumpAndSettle();
    expect(find.text('Title help'), findsOneWidget);
    expect(find.text('Title diy'), findsNothing);

    await tester.tap(find.byKey(const Key('pulse_filter_diy')));
    await tester.pumpAndSettle();
    expect(find.text('Title diy'), findsOneWidget);
    expect(find.text('Title help'), findsNothing);

    await tester.tap(find.byKey(const Key('pulse_filter_mostVoted')));
    await tester.pumpAndSettle();
    final chatY = tester.getTopLeft(find.text('Title chat')).dy;
    final helpY = tester.getTopLeft(find.text('Title help')).dy;
    expect(chatY, lessThan(helpY));
    expect(find.text('Title diy'), findsNothing);
  });

  testWidgets('bookmarking a post puts it in Saved', (tester) async {
    await pump(tester);

    final bookmark = find.descendant(
      of: find.byKey(const Key('pulse_post_diy')),
      matching: find.byIcon(Icons.bookmark_border),
    );
    await tester.ensureVisible(bookmark);
    await tester.tap(bookmark);
    await tester.pumpAndSettle();

    final savedChip = find.byKey(const Key('pulse_filter_saved'));
    await tester.ensureVisible(savedChip);
    await tester.pumpAndSettle();
    await tester.tap(savedChip);
    await tester.pumpAndSettle();
    expect(find.text('Title diy'), findsOneWidget);
    expect(find.text('Title help'), findsNothing);
  });

  testWidgets('no sources shows the empty state that leads to Hubs', (tester) async {
    await pump(tester, s: PulseSources.empty, list: const []);
    expect(find.text('Your pit wall is quiet'), findsOneWidget);
    expect(find.text('Explore hubs'), findsOneWidget);
  });
}
