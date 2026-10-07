import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/app.dart';

void main() {
  // issues §101.C5: authStateProvider is userChanges(), which also fires on
  // token refreshes and profile reloads. Only a uid change acts.
  group('authSideEffect', () {
    test('signing in', () {
      expect(authSideEffect(null, 'a'), AuthSideEffect.signedIn);
    });

    test('token refresh / profile reload for the same rider does nothing', () {
      expect(authSideEffect('a', 'a'), AuthSideEffect.none);
    });

    test('signing out', () {
      expect(authSideEffect('a', null), AuthSideEffect.signedOut);
    });

    test('an error emission does nothing', () {
      expect(authSideEffect('a', null, isError: true), AuthSideEffect.none);
      expect(authSideEffect(null, null, isError: true), AuthSideEffect.none);
    });

    test('switching accounts is a sign-in', () {
      expect(authSideEffect('a', 'b'), AuthSideEffect.signedIn);
    });

    test('still signed out does nothing', () {
      expect(authSideEffect(null, null), AuthSideEffect.none);
    });
  });

  // issues §101.C9: the fallback used the app's own context for l10n, which
  // has no Localizations ancestor, so the error screen itself threw.
  testWidgets('AppInitErrorScreen renders with no surrounding MaterialApp',
      (tester) async {
    await tester.pumpWidget(AppInitErrorScreen(error: StateError('kaput')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('kaput'), findsOneWidget);
  });
}
