import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/chat/data/repositories/chat_repository.dart';
import 'package:throttleiq/features/chat/domain/entities/chat_entity.dart';
import 'package:throttleiq/features/chat/presentation/providers/chat_providers.dart';
import 'package:throttleiq/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';
import 'package:throttleiq/features/profile/presentation/widgets/profile_load_error_view.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  group('ChatRepository.dmId', () {
    test('is the same whichever rider opens the chat', () {
      expect(ChatRepository.dmId('alice', 'bob'), ChatRepository.dmId('bob', 'alice'));
    });

    test('is the sorted pair joined with _ (what firestore.rules checks)', () {
      expect(ChatRepository.dmId('zed', 'amy'), 'amy_zed');
      expect(ChatRepository.dmId('amy', 'zed'), 'amy_zed');
    });
  });

  group('visibleChats', () {
    final t = DateTime.utc(2026);
    final chats = [
      ChatEntity(id: 'a', participants: const ['me', 'friend'], updatedAt: t),
      ChatEntity(id: 'b', participants: const ['me', 'troll'], updatedAt: t),
      ChatEntity(id: 'c', participants: const ['troll2', 'me'], updatedAt: t),
    ];

    test('hides chats with blocked riders', () {
      final visible = visibleChats(chats, myUid: 'me', blocked: {'troll', 'troll2'});
      expect(visible.map((c) => c.id), ['a']);
    });

    test('returns everything when nobody is blocked', () {
      expect(visibleChats(chats, myUid: 'me', blocked: const {}), chats);
    });
  });

  group('ChatRoomScreen block banner', () {
    Widget room({required bool blocked}) => ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            chatMessagesProvider('c1').overrideWith((ref) => Stream.value(const [])),
            singleChatProvider('c1').overrideWith((ref) async => null),
            chatBlockedProvider('other').overrideWith((ref) async => blocked),
          ],
          child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
            home: ChatRoomScreen(
              chatId: 'c1',
              otherUser: UserProfileEntity(uid: 'other', displayName: 'Other'),
            ),
          ),
        );

    testWidgets('blocked: banner shown, composer gone', (tester) async {
      await tester.pumpWidget(room(blocked: true));
      await tester.pumpAndSettle();
      expect(find.text("You can't message this rider"), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('not blocked: composer shown, no banner', (tester) async {
      await tester.pumpWidget(room(blocked: false));
      await tester.pumpAndSettle();
      expect(find.text("You can't message this rider"), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('classifyProfileError', () {
    test('permission-denied is private', () {
      expect(
        classifyProfileError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
        ProfileLoadFailure.private,
      );
    });

    test('unavailable / deadline-exceeded are offline', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          classifyProfileError(FirebaseException(plugin: 'cloud_firestore', code: code)),
          ProfileLoadFailure.offline,
        );
      }
    });

    test('anything else is a generic failure', () {
      expect(
        classifyProfileError(FirebaseException(plugin: 'cloud_firestore', code: 'internal')),
        ProfileLoadFailure.other,
      );
      expect(classifyProfileError(StateError('x')), ProfileLoadFailure.other);
    });

    testWidgets('offline view offers Retry; private view does not', (tester) async {
      var retried = 0;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileLoadErrorView(
            failure: ProfileLoadFailure.offline,
            onRetry: () => retried++,
          ),
        ),
      ));
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileLoadErrorView(
            failure: ProfileLoadFailure.private,
            onRetry: () => retried++,
          ),
        ),
      ));
      expect(find.text('This profile is private'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });
}
