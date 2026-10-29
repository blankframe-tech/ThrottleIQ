import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/auth/presentation/screens/register_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Register screen (#24, §83.28): validation blocks a bad form before any
/// network call, a good form reaches the auth notifier with the email
/// trimmed, and a Firebase rejection reaches the rider in words. Large text
/// and Bangla are covered by text_scale_sweep_test.dart.
class _FakeAuth extends StateNotifier<AsyncValue<void>>
    implements AuthNotifier {
  _FakeAuth({this.reject}) : super(const AsyncValue.data(null));

  final FirebaseAuthException? reject;
  final registrations = <(String, String)>[];

  @override
  Future<void> register(String email, String password) async {
    registrations.add((email, password));
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
      initialLocation: '/auth/register',
      routes: [
        GoRoute(
            path: '/auth/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(
            path: '/auth/login',
            builder: (_, __) => const Scaffold(body: Text('Login page'))),
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
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty form shows the errors and registers nobody',
      (tester) async {
    await pump(tester);
    expect(find.text('Join ThrottleIQ'), findsOneWidget);
    await submit(tester);

    expect(find.text('Email required'), findsOneWidget);
    expect(find.text('Min 6 characters'), findsOneWidget);
    expect(auth.registrations, isEmpty);
  });

  testWidgets('an address without @ is rejected', (tester) async {
    await pump(tester);
    await tester.enterText(field(0), 'rider.example.com');
    await tester.enterText(field(1), 'secret123');
    await tester.enterText(field(2), 'secret123');
    await submit(tester);

    expect(find.text('Invalid email'), findsOneWidget);
    expect(auth.registrations, isEmpty);
  });

  testWidgets('a mismatched confirmation is rejected', (tester) async {
    await pump(tester);
    await tester.enterText(field(0), 'rider@example.com');
    await tester.enterText(field(1), 'secret123');
    await tester.enterText(field(2), 'secret124');
    await submit(tester);

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.registrations, isEmpty);
  });

  testWidgets('a valid form registers with the email trimmed', (tester) async {
    await pump(tester);
    await tester.enterText(field(0), '  rider@example.com ');
    await tester.enterText(field(1), 'secret123');
    await tester.enterText(field(2), 'secret123');
    await submit(tester);

    expect(auth.registrations, [('rider@example.com', 'secret123')]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an email already in use is explained in a SnackBar',
      (tester) async {
    await pump(tester,
        reject: FirebaseAuthException(code: 'email-already-in-use'));
    await tester.enterText(field(0), 'rider@example.com');
    await tester.enterText(field(1), 'secret123');
    await tester.enterText(field(2), 'secret123');
    await submit(tester);

    expect(auth.registrations, hasLength(1));
    expect(find.text('An account with this email already exists.'),
        findsOneWidget);
  });

  for (final (name, target) in [
    ('Back', find.byTooltip('Back')),
    ('"Sign In"', find.text('Sign In')),
  ]) {
    testWidgets('$name returns to the login page', (tester) async {
      await pump(tester);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('Login page'), findsOneWidget);
    });
  }
}
