import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

void main() {
  const all = AppModules();
  const forumsOnly = AppModules(community: CommunityMode.forumsOnly);
  const minimal = AppModules(community: CommunityMode.off, places: false);
  const maintenanceOnly = AppModules(
      community: CommunityMode.off, places: false, rideTracking: false);

  group('tabs', () {
    test('everything on is the classic five-tab bar', () {
      expect(all.tabs, shellTabs);
    });

    test('forums-only keeps the first tab (shown as Forums)', () {
      expect(forumsOnly.tabs, shellTabs);
    });

    test('community and places off leaves record, rides and garage', () {
      expect(minimal.tabs, ['/home/record', '/home/stats', '/home/profile']);
    });

    test('tracking off swaps Record and Rides for Maintenance', () {
      expect(const AppModules(rideTracking: false).tabs, [
        '/home/social',
        '/home/places',
        '/home/maintenance',
        '/home/profile',
      ]);
      expect(maintenanceOnly.tabs, ['/home/maintenance', '/home/profile']);
      expect(maintenanceOnly.home, '/home/maintenance');
    });
  });

  group('redirectFor', () {
    test('nothing is blocked with everything on', () {
      for (final loc in [
        '/home/social',
        '/people/all',
        '/chats/abc',
        '/profile/uid1',
        '/group-ride/g1',
        '/forums/f1/post/p1',
        '/home/places/add',
        '/routes/r1/navigate',
        '/ride/summary/r1',
        '/home/stats',
      ]) {
        expect(all.redirectFor(loc), isNull, reason: loc);
      }
    });

    test('forums-only blocks people, chat, follows and group rides', () {
      for (final loc in [
        '/people/all',
        '/chats',
        '/chats/abc',
        '/notifications',
        '/profile/uid1',
        '/profile/qr',
        '/profile/scan',
        '/rides/shared/r1',
        '/rides/mine',
        '/ride/share/r1',
        '/group-ride/g1',
      ]) {
        expect(forumsOnly.redirectFor(loc), '/home/record', reason: loc);
      }
      for (final loc in [
        '/home/social',
        '/forums/f1',
        '/forums/f1/post/p1',
        '/profile',
        '/profile/edit',
        '/ride/summary/r1',
      ]) {
        expect(forumsOnly.redirectFor(loc), isNull, reason: loc);
      }
    });

    test('community off also blocks forums and the Social tab', () {
      expect(minimal.redirectFor('/forums/f1'), '/home/record');
      expect(minimal.redirectFor('/forums/create'), '/home/record');
      expect(minimal.redirectFor('/home/social'), '/home/record');
    });

    test('places off blocks places and routes', () {
      for (final loc in [
        '/home/places',
        '/home/places/abc',
        '/places/mine',
        '/routes',
        '/routes/r1',
        '/routes/save/r1',
      ]) {
        expect(minimal.redirectFor(loc), '/home/record', reason: loc);
      }
    });

    test('tracking off blocks recording, rides and analytics', () {
      const noTracking = AppModules(rideTracking: false);
      for (final loc in [
        '/home/record',
        '/home/stats',
        '/ride/active',
        '/ride/summary/r1',
        '/rides/all',
        '/group-ride/g1',
        '/routes/save/r1',
        '/routes/r1/navigate',
      ]) {
        expect(noTracking.redirectFor(loc), '/home/maintenance', reason: loc);
      }
      // Viewing a route, other riders' shared rides and maintenance is fine.
      for (final loc in [
        '/routes/r1',
        '/rides/shared/r1',
        '/home/maintenance',
        '/home/maintenance/add',
        '/home/profile/b1',
        '/settings',
      ]) {
        expect(noTracking.redirectFor(loc), isNull, reason: loc);
      }
    });

    test('home is never redirected (no redirect loop)', () {
      for (final m in [all, forumsOnly, minimal, maintenanceOnly]) {
        expect(m.redirectFor(m.home), isNull);
      }
    });

    test('segment boundaries are respected', () {
      expect(minimal.redirectFor('/forumsx'), isNull);
      expect(forumsOnly.redirectFor('/profilex'), isNull);
    });
  });

  group('shellTabIndexForLocation with modules', () {
    test('maintenance is its own tab with tracking off', () {
      expect(shellTabIndexForLocation('/home/maintenance', maintenanceOnly), 0);
      expect(
          shellTabIndexForLocation(
              '/home/maintenance/add?bikeId=b', maintenanceOnly),
          0);
      expect(shellTabIndexForLocation('/home/profile/b1', maintenanceOnly), 1);
    });

    test('maintenance highlights Garage while tracking is on', () {
      expect(shellTabIndexForLocation('/home/maintenance', minimal), 2);
    });

    test('unknown falls back to the home tab', () {
      expect(shellTabIndexForLocation('/nowhere', maintenanceOnly), 0);
      expect(shellTabIndexForLocation('/nowhere', minimal), 0);
    });
  });

  group('AppModulesNotifier', () {
    test('defaults to everything on', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appModulesProvider);
      await Future<void>.delayed(Duration.zero);
      final m = container.read(appModulesProvider);
      expect(m.community, CommunityMode.full);
      expect(m.places, isTrue);
      expect(m.rideTracking, isTrue);
    });

    test('a saved choice survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(appModulesProvider.notifier).set(maintenanceOnly);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(appModulesProvider);
      await Future<void>.delayed(Duration.zero);
      final m = second.read(appModulesProvider);
      expect(m.community, CommunityMode.off);
      expect(m.places, isFalse);
      expect(m.rideTracking, isFalse);
    });

    test('an unknown stored community value falls back to full', () async {
      SharedPreferences.setMockInitialValues({'module_community': 'bogus'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appModulesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appModulesProvider).community, CommunityMode.full);
    });
  });
}
