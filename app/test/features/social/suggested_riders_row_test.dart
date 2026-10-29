import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/follow_providers.dart';
import 'package:throttleiq/features/social/presentation/screens/social_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
}

/// Issue #20: the "Suggested for you" cards overflowed their fixed-height
/// row. The row now sizes to its tallest card.
void main() {
  for (final (locale, scale) in [
    (const Locale('en'), 1.0),
    (const Locale('bn'), 1.3),
    (const Locale('en'), 2.0),
  ]) {
    testWidgets('suggested rider cards fit (${locale.languageCode}, ${scale}x)',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_FakeUser()),
          followingUidsProvider.overrideWith((ref) => Stream.value({})),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SuggestedRidersRow([
              UserProfileEntity(uid: 'a', displayName: 'রাকিবুল ইসলাম'),
              UserProfileEntity(uid: 'b', displayName: 'Rider B'),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
    });
  }
}
