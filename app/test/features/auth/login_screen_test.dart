import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/auth/presentation/screens/login_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Sign-in screen (§83.28): validation blocks a bad form before any network
/// call, a good form reaches the auth notifier with the email trimmed, and a
/// Firebase rejection reaches the rider in words.
class _FakeAuth extends StateNotifier<AsyncValue<void>>
    implements AuthNotifier {
  _FakeAuth({this.reject}) : super(const AsyncValue.data(null));

  final FirebaseAuthException? reject;
  final signIns = <(String, String)>[];

  @override
  Future<void> signIn(String email, String password) async {
    signIns.add((email, password));
    state = reject == null
        ? const AsyncValue.data(null)
        : AsyncValue.error(reject!, StackTrace.empty);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuth auth;

  Future<void> pump(WidgetTester tester,
      {FirebaseAuthException? reject}) async {
    auth = _FakeAuth(reject: reject);
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: '/auth/register',
            builder: (_, __) => const Scaffold(body: Text('Register page'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authNotifierProvider.overrideWith((ref) => auth)],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(int i) => find.byType(TextFormField).at(i);

  testWidgets('an empty form shows both errors and signs nobody in',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Email required'), findsOneWidget);
    expect(find.text('Password too short'), findsOneWidget);
    expect(auth.signIns, isEmpty);
  });

  testWidgets('an address without @ is rejected', (tester) async {
    await pump(tester);
    await tester.enterText(field(0), 'rider.example.com');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email'), findsOneWidget);
    expect(auth.signIns, isEmpty);
  });

  testWidgets('a valid form signs in with the email trimmed', (tester) async {
    await pump(tester);
    await tester.enterText(field(0), '  rider@example.com ');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(auth.signIns, [('rider@example.com', 'secret123')]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a wrong password is explained in a SnackBar', (tester) async {
    await pump(tester, reject: FirebaseAuthException(code: 'wrong-password'));
    await tester.enterText(field(0), 'rider@example.com');
    await tester.enterText(field(1), 'wrongpass');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(auth.signIns, hasLength(1));
    expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
  });

  testWidgets('the eye button reveals and hides the password', (tester) async {
    await pump(tester);
    EditableText password() => tester.widget<EditableText>(
        find.descendant(of: field(1), matching: find.byType(EditableText)));

    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isTrue);
  });

  testWidgets('"Sign Up" opens the register page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Register page'), findsOneWidget);
  });
}
