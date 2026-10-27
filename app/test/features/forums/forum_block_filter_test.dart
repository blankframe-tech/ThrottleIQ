import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:throttleiq/features/forums/data/repositories/forum_repository.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_post_entity.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_reply_entity.dart';
import 'package:throttleiq/features/forums/presentation/screens/forum_post_detail_screen.dart';
import 'package:throttleiq/features/profile/presentation/providers/profile_providers.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Critique 2026-10-27 #3: replies from a rider the viewer blocked must not
/// be shown.
class _Repo extends Mock implements ForumRepository {
  final _at = DateTime(2026, 10, 27);

  @override
  Future<ForumPostEntity?> getPost(
          {required String forumId, required String postId}) async =>
      ForumPostEntity(
          id: postId,
          forumId: forumId,
          userId: 'author',
          userName: 'Author',
          title: 'Chain slack?',
          body: 'How much?',
          createdAt: _at);

  @override
  Future<List<ForumReplyEntity>> getReplies(
          {required String forumId, required String postId}) async =>
      [
        for (final (uid, body) in [
          ('friend', 'Friendly reply'),
          ('harasser', 'Blocked reply'),
        ])
          ForumReplyEntity(
              id: uid,
              postId: postId,
              forumId: forumId,
              userId: uid,
              userName: uid,
              body: body,
              createdAt: _at),
      ];
}

void main() {
  testWidgets('post detail hides replies from blocked riders', (tester) async {
    ForumRepository.instanceForTest = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        blockedUsersProvider.overrideWith((ref) async => {'harasser'}),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ForumPostDetailScreen(forumId: 'f1', postId: 'p1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Friendly reply'), findsOneWidget);
    expect(find.text('Blocked reply'), findsNothing);
    expect(find.text('1 reply'), findsOneWidget);
  });
}
