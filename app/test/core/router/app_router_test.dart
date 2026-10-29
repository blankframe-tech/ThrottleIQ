import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/router/app_router.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

void main() {
  group('computeAuthRedirect', () {
    test('never redirects away from /splash (splash owns its own navigation)',
        () {
      expect(
        computeAuthRedirect(isAuth: true, isOnboarding: true, loc: '/splash'),
        isNull,
      );
    });

    test('sends a signed-out user to login', () {
      expect(
        computeAuthRedirect(
            isAuth: false, isOnboarding: true, loc: '/home/record'),
        '/auth/login',
      );
    });

    test('sends a signed-in, onboarding user to onboarding', () {
      expect(
        computeAuthRedirect(
            isAuth: true, isOnboarding: true, loc: '/home/record'),
        '/auth/onboarding',
      );
    });

    test(
      'regression: a user who just finished onboarding (isOnboarding flips to '
      'false) is NOT bounced back to onboarding — this was the "add bike '
      'loops forever" bug, caused by the redirect closure never seeing the '
      'post-onboarding auth state',
      () {
        expect(
          computeAuthRedirect(
              isAuth: true, isOnboarding: false, loc: '/auth/onboarding'),
          isNull,
        );
        expect(
          computeAuthRedirect(
              isAuth: true, isOnboarding: false, loc: '/home/record'),
          isNull,
        );
      },
    );

    test('sends an authenticated, non-onboarding user away from /auth screens',
        () {
      expect(
        computeAuthRedirect(
            isAuth: true, isOnboarding: false, loc: '/auth/login'),
        '/home/record',
      );
    });

    test('does not touch a signed-in, non-onboarding user browsing /home/*',
        () {
      expect(
        computeAuthRedirect(
            isAuth: true, isOnboarding: false, loc: '/home/profile/add'),
        isNull,
      );
    });

    test(
      'regression: /auth/register is treated like /auth/login by the redirect '
      '— a signed-out user hitting it stays put, and a signed-in user is sent '
      'home. Guards against the route existing in computeAuthRedirect\'s '
      'startsWith("/auth") branch but never being registered in the GoRouter '
      'routes list (the "no routes for location: /auth/register" bug).',
      () {
        expect(
          computeAuthRedirect(
              isAuth: false, isOnboarding: true, loc: '/auth/register'),
          isNull,
        );
        expect(
          computeAuthRedirect(
              isAuth: true, isOnboarding: false, loc: '/auth/register'),
          '/home/record',
        );
      },
    );
  });

  // #61: every tab is its own branch, so switching tabs keeps each tab's
  // state and scroll position instead of rebuilding the screen.
  test('each bottom-nav tab is its own StatefulShellRoute branch', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);

    final shell = container
        .read(routerProvider)
        .configuration
        .routes
        .whereType<StatefulShellRoute>()
        .single;
    final roots = [
      for (final b in shell.branches) (b.routes.single as GoRoute).path,
    ];
    expect(roots.toSet(), {...shellTabs, '/home/maintenance'});
    expect(roots.length, roots.toSet().length);
  });
}
