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
        computeAuthRedirect(isAuth: true, isOnboarding: false, loc: '/home/garage/add'),
        isNull,
      );
    });
  });
}
