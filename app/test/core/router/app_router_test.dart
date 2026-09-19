import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/router/app_router.dart' show computeAuthRedirect;

void main() {
  group('computeAuthRedirect', () {
    test('never redirects away from /splash (splash owns its own navigation)', () {
      expect(
        computeAuthRedirect(isAuth: true, isOnboarding: true, loc: '/splash'),
        isNull,
      );
    });

    test('sends a signed-out user to login', () {
      expect(
        computeAuthRedirect(isAuth: false, isOnboarding: true, loc: '/home/record'),
        '/auth/login',
      );
    });

    test('sends a signed-in, onboarding user to onboarding', () {
      expect(
        computeAuthRedirect(isAuth: true, isOnboarding: true, loc: '/home/record'),
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
          computeAuthRedirect(isAuth: true, isOnboarding: false, loc: '/auth/onboarding'),
          isNull,
        );
        expect(
          computeAuthRedirect(isAuth: true, isOnboarding: false, loc: '/home/record'),
          isNull,
        );
      },
    );

    test('sends an authenticated, non-onboarding user away from /auth screens', () {
      expect(
        computeAuthRedirect(isAuth: true, isOnboarding: false, loc: '/auth/login'),
        '/home/record',
      );
    });

    test('does not touch a signed-in, non-onboarding user browsing /home/*', () {
      expect(
        computeAuthRedirect(isAuth: true, isOnboarding: false, loc: '/home/profile/add'),
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
          computeAuthRedirect(isAuth: false, isOnboarding: true, loc: '/auth/register'),
          isNull,
        );
        expect(
          computeAuthRedirect(isAuth: true, isOnboarding: false, loc: '/auth/register'),
          '/home/record',
        );
      },
    );
  });
}
