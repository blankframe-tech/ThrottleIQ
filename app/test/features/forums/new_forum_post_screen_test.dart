import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/forums/domain/forum_directory.dart';
import 'package:throttleiq/features/forums/presentation/providers/forum_providers.dart';
import 'package:throttleiq/features/forums/presentation/screens/new_forum_post_screen.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'rider-1';
}

/// Write first, pick groups on Share (owner, 2026-10-25).
void main() {
  group('forumPostTargets', () {
    test('no group lands in All Riders', () {
      final (home, alsoIn) = forumPostTargets(const []);
      expect(home, kAllRidersForumId);
      expect(alsoIn, isEmpty);
    });

    test('the first pick is home, the rest go in alsoIn', () {
      final (home, alsoIn) = forumPostTargets(const ['a', 'b', 'c']);
      expect(home, 'a');
      expect(alsoIn, ['b', 'c']);
    });

    test('All Riders and repeats are dropped, five at most', () {
      final (home, alsoIn) = forumPostTargets(
          [kAllRidersForumId, 'a', 'a', 'b', 'c', 'd', 'e', 'f']);
      expect(home, 'a');
      expect(alsoIn, ['b', 'c', 'd', 'e']);
    });
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_FakeUser()),
          activeBikeProvider.overrideWithValue(null),
          pulseSourcesProvider.overrideWith((ref) async => const PulseSources(
                forumIds: ['honda-shine'],
                names: {'honda-shine': 'Honda Shine'},
                garageForumIds: {'honda-shine'},
              )),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NewForumPostScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens straight on the title and body, no group question first',
      (tester) async {
    await pumpComposer(tester);
    expect(find.byKey(const Key('post_title')), findsOneWidget);
    expect(find.byKey(const Key('post_body')), findsOneWidget);
    expect(find.byKey(const Key('post_add_photo')), findsOneWidget);
    expect(find.byKey(const Key('share_group_all_riders')), findsNothing);
  });

  testWidgets('Share with an empty post shows the errors, not the groups',
      (tester) async {
    await pumpComposer(tester);
    await tester.tap(find.byKey(const Key('post_share')));
    await tester.pumpAndSettle();
    expect(find.text('Title is required'), findsOneWidget);
    expect(find.byKey(const Key('share_group_all_riders')), findsNothing);
  });

  testWidgets('Share asks for groups: All Riders always, five picks at most',
      (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byKey(const Key('post_title')), 'Chain noise');
    await tester.enterText(find.byKey(const Key('post_body')), 'Clicks at 40');
    await tester.tap(find.byKey(const Key('post_share')));
    await tester.pumpAndSettle();

    final allRiders = tester.widget<CheckboxListTile>(
        find.byKey(const Key('share_group_all_riders')));
    expect(allRiders.value, isTrue);
    expect(allRiders.onChanged, isNull, reason: 'cannot be unticked');
    expect(find.byKey(const Key('share_group_honda-shine')), findsOneWidget);

    final ids = [
      'honda-shine',
      for (final b in TopicBoard.values.take(5)) b.slug,
    ];
    for (final id in ids.take(kForumPostMaxGroups)) {
      final tile = find.byKey(Key('share_group_$id'));
      await tester.scrollUntilVisible(tile, 80,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(tile);
      await tester.pump();
    }
    expect(find.text('5 of 5 groups'), findsOneWidget);

    final sixth = find.byKey(Key('share_group_${ids.last}'));
    await tester.scrollUntilVisible(sixth, 80,
        scrollable: find.byType(Scrollable).last);
    expect(tester.widget<CheckboxListTile>(sixth).onChanged, isNull,
        reason: 'a sixth group is refused');
  });
}
