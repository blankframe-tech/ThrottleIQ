import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/profile/data/repositories/profile_repository.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';
import 'package:throttleiq/features/profile/presentation/providers/profile_providers.dart';
import 'package:throttleiq/features/social/domain/utilities/follow_link.dart';
import 'package:throttleiq/features/social/domain/utilities/follow_link_outcome.dart';
import 'package:throttleiq/features/social/presentation/providers/follow_link_providers.dart';
import 'package:throttleiq/features/social/presentation/providers/follow_providers.dart';
import 'package:throttleiq/features/social/presentation/widgets/confirm_follow_dialog.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
}

class _FakeProfiles extends Fake implements ProfileRepository {
  _FakeProfiles({this.deny = false});
  final bool deny;

  @override
  Future<UserProfileEntity?> getProfile(String uid) async {
    if (deny) throw Exception('permission-denied');
    return UserProfileEntity(uid: uid, displayName: 'Stranger');
  }
}

class _FakeFollow extends Fake implements FollowController {
  final followed = <String>[];

  @override
  Future<void> setFollowing(String targetUid,
      {required bool follow, required String fallbackName}) async {
    if (follow) followed.add(targetUid);
  }
}

/// A follow link can come from anyone, so every entry point (an https App
/// Link, the throttleiq:// scheme, a scanned QR code) asks "Follow <name>?"
/// and writes nothing until the Follow tap.
void main() {
  const uid = 'attackerUid123';
  final forms = {
    'https link': 'https://www.blankframe.tech/ThrottleIQ/u/$uid',
    'custom scheme': 'throttleiq://u/$uid',
    // The QR encodes the canonical link; the scanner parses it the same way.
    'QR code': buildFollowLink(uid).toString(),
  };

  Future<(_FakeFollow, Future<FollowLinkResult> Function())> pump(
      WidgetTester tester, String link,
      {bool deny = false}) async {
    final follow = _FakeFollow();
    late BuildContext ctx;
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_FakeUser()),
        followingUidsProvider.overrideWith((ref) => Stream.value(const {})),
        profileRepositoryProvider.overrideWithValue(_FakeProfiles(deny: deny)),
        followControllerProvider.overrideWithValue(follow),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(builder: (context, ref, _) {
          ctx = context;
          container = ProviderScope.containerOf(context);
          return const Scaffold();
        }),
      ),
    ));
    Future<FollowLinkResult> run() => container
        .read(followLinkControllerProvider)
        .followUid(parseFollowLink(link),
            l10n: AppLocalizations.of(ctx),
            confirm: (name) => confirmFollowFromLink(ctx, name));
    return (follow, run);
  }

  forms.forEach((form, link) {
    testWidgets('$form: confirm first, follow only on the Follow tap',
        (tester) async {
      final (follow, run) = await pump(tester, link);
      final result = run();
      await tester.pumpAndSettle();

      expect(find.text('Follow Stranger?'), findsOneWidget);
      expect(follow.followed, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Follow'));
      await tester.pumpAndSettle();
      expect((await result).outcome, FollowLinkOutcome.followed);
      expect(follow.followed, [uid]);
    });

    testWidgets('$form: Cancel writes nothing', (tester) async {
      final (follow, run) = await pump(tester, link);
      final result = run();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect((await result).outcome, FollowLinkOutcome.cancelled);
      expect(follow.followed, isEmpty);
    });
  });

  testWidgets('an unreadable profile follows nobody and asks nothing',
      (tester) async {
    final (follow, run) = await pump(tester, forms['https link']!, deny: true);
    final result = run();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect((await result).outcome, FollowLinkOutcome.unavailable);
    expect(follow.followed, isEmpty);
  });
}
