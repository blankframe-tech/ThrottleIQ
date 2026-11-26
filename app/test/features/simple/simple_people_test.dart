import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';
import 'package:throttleiq/features/profile/presentation/providers/profile_providers.dart';
import 'package:throttleiq/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_people_screen.dart';
import 'package:throttleiq/features/social/presentation/providers/follow_providers.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';
import 'package:throttleiq/features/social/presentation/widgets/follow_button.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
}

class _Modules extends StateNotifier<AppModules> implements AppModulesNotifier {
  _Modules(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Simple mode keeps People (find riders, follow them) and nothing else of
/// community: no ride feed, forums or chat.
void main() {
  final en = AppLocalizationsEn();
  const rider = UserProfileEntity(uid: 'r2', displayName: 'Tanvir Ahmed');

  Future<void> pump(WidgetTester tester, Widget home,
      {AppModules modules = const AppModules(simple: true)}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appModulesProvider.overrideWith((ref) => _Modules(modules)),
        currentUserProvider.overrideWithValue(_FakeUser()),
        followingUidsProvider.overrideWith((ref) => Stream.value(<String>{})),
        suggestedProfilesProvider.overrideWith((ref) async => const [rider]),
        profileProvider.overrideWith((ref, uid) => Stream.value(rider)),
        riderBikesProvider.overrideWith((ref, uid) async => const []),
        riderSharedRidesProvider.overrideWith((ref, uid) async => const []),
        followerCountProvider.overrideWith((ref, uid) async => 3),
        followingCountProvider.overrideWith((ref, uid) async => 5),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  // Disposes the scope, which cancels the follow lists' keep-alive timers.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('the People tab: rider search, suggestions, who you follow',
      (tester) async {
    await pump(tester, const SimplePeopleScreen());
    expect(find.text(en.peopleTabLabel), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tanvir Ahmed'), findsOneWidget);
    // Simple's sentence-case headings, not the full app's all-caps labels.
    expect(find.text(en.suggestedForYou), findsOneWidget);
    expect(find.text(en.following), findsOneWidget);
    expect(find.text(en.following.toUpperCase()), findsNothing);
    // The emergency button is on this tab too.
    expect(find.byKey(const Key('simple_home_help')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("another rider's profile: Follow, but no Message in Simple",
      (tester) async {
    await pump(tester, const UserProfileScreen(uid: 'r2'));
    expect(find.byType(FollowButton), findsOneWidget);
    expect(find.text(en.message), findsNothing);
    expect(find.text(en.followersLabel), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the full app still offers Message', (tester) async {
    await pump(tester, const UserProfileScreen(uid: 'r2'),
        modules: const AppModules());
    expect(find.byType(FollowButton), findsOneWidget);
    expect(find.text(en.message), findsOneWidget);
    await unmount(tester);
  });
}
