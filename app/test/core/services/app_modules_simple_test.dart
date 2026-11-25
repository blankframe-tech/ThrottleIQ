import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

/// Simple mode (ThrottleEZ, #240): the AppModules side of the switch.
void main() {
  const simple = AppModules(simple: true);
  const simpleNoTracking = AppModules(simple: true, rideTracking: false);

  test('off by default, and copyWith carries it', () {
    expect(const AppModules().simple, isFalse);
    expect(const AppModules().copyWith(simple: true).simple, isTrue);
    expect(simple.copyWith(places: false).simple, isTrue);
  });

  test('simple hides social and forums whatever the community choice', () {
    for (final mode in CommunityMode.values) {
      final m = AppModules(community: mode, simple: true);
      expect(m.social, isFalse, reason: mode.name);
      expect(m.forums, isFalse, reason: mode.name);
    }
  });

  group('tabs and home', () {
    test('three tabs: Home, Rides, Bike', () {
      expect(simple.tabs,
          ['/home/simple', '/home/simple-rides', '/home/simple-bike']);
      expect(simple.home, '/home/simple');
    });

    test('no Rides tab with ride tracking off', () {
      expect(simpleNoTracking.tabs, ['/home/simple', '/home/simple-bike']);
      expect(simpleNoTracking.home, '/home/simple');
    });

    test('places and community do not change the simple tabs', () {
      const m =
          AppModules(simple: true, places: false, community: CommunityMode.off);
      expect(m.tabs, simple.tabs);
    });
  });

  group('redirectFor in simple mode', () {
    test('the maintenance tab root goes to the Bike tab', () {
      expect(simple.redirectFor('/home/maintenance'), '/home/simple-bike');
      expect(simple.redirectFor('/home/maintenance?bikeId=b1'),
          '/home/simple-bike');
    });

    test('hidden areas land on the simple home', () {
      for (final loc in [
        '/home/record',
        '/home/stats',
        '/home/social',
        '/home/places',
        '/home/places/add',
        '/home/places/p1',
        '/places/mine',
        '/routes',
        '/routes/r1',
        '/routes/save/r1',
        '/routes/r1/navigate',
        '/rides/all',
        '/home/profile',
        // The existing social and forum rules, through the getters.
        '/forums/f1',
        '/forums/create',
        '/people/all',
        '/chats',
        '/chats/c1',
        '/notifications',
        '/group-ride/g1',
        '/rides/shared/r1',
        '/rides/mine',
        '/ride/share/r1',
        '/profile/uid1',
        '/profile/qr',
        '/profile/scan',
      ]) {
        expect(simple.redirectFor(loc), '/home/simple', reason: loc);
      }
    });

    test('the bike, maintenance, ride and settings screens stay reachable', () {
      for (final loc in [
        '/home/simple',
        '/home/simple-rides',
        '/home/simple-rides/r1',
        '/home/simple-bike',
        '/home/profile/add',
        '/home/profile/b1',
        '/home/profile/b1/edit',
        '/home/maintenance/fuel',
        '/home/maintenance/fuel/add?bikeId=b1',
        '/home/maintenance/add?bikeId=b1',
        '/home/maintenance/setup?bikeId=b1&firstTime=true',
        '/home/maintenance/configure',
        '/home/maintenance/check',
        '/home/maintenance/records',
        '/ride/active',
        '/ride/summary/r1',
        '/settings',
        '/settings/advanced',
        '/safe-qr',
        '/sync-issues',
        '/blocked-users',
        '/profile',
        '/profile/edit',
      ]) {
        expect(simple.redirectFor(loc), isNull, reason: loc);
      }
    });

    test('no Rides tab (or recording) with ride tracking off', () {
      for (final loc in [
        '/home/simple-rides',
        '/home/simple-rides/r1',
        '/ride/active',
        '/ride/summary/r1',
      ]) {
        expect(simpleNoTracking.redirectFor(loc), '/home/simple', reason: loc);
      }
      expect(simpleNoTracking.redirectFor('/home/simple-bike'), isNull);
    });

    test('home is never redirected (no redirect loop)', () {
      for (final m in [simple, simpleNoTracking]) {
        expect(m.redirectFor(m.home), isNull);
        for (final tab in m.tabs) {
          expect(m.redirectFor(tab), isNull, reason: tab);
        }
      }
    });
  });

  group('redirectFor in full mode', () {
    test('the simple tabs go to the full-mode home', () {
      for (final loc in [
        '/home/simple',
        '/home/simple-rides',
        '/home/simple-rides/r1',
        '/home/simple-bike',
      ]) {
        expect(const AppModules().redirectFor(loc), '/home/record',
            reason: loc);
        expect(const AppModules(rideTracking: false).redirectFor(loc),
            '/home/maintenance',
            reason: loc);
      }
    });

    test('segment boundaries are respected', () {
      expect(const AppModules().redirectFor('/home/simplex'), isNull);
    });
  });

  group('shellTabIndexForLocation in simple mode', () {
    test('each tab highlights itself', () {
      expect(shellTabIndexForLocation('/home/simple', simple), 0);
      expect(shellTabIndexForLocation('/home/simple-rides/r1', simple), 1);
      expect(shellTabIndexForLocation('/home/simple-bike', simple), 2);
      expect(
          shellTabIndexForLocation('/home/simple-bike', simpleNoTracking), 1);
    });

    test('maintenance and bike screens highlight the Bike tab', () {
      for (final loc in [
        '/home/maintenance',
        '/home/maintenance/fuel/add?bikeId=b1',
        '/home/profile/add',
        '/home/profile/b1/edit',
      ]) {
        expect(shellTabIndexForLocation(loc, simple), 2, reason: loc);
        expect(shellTabIndexForLocation(loc, simpleNoTracking), 1, reason: loc);
      }
    });

    test('unknown falls back to the simple home', () {
      expect(shellTabIndexForLocation('/nowhere', simple), 0);
    });
  });

  group('AppModulesNotifier', () {
    test('module_simple defaults to off', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appModulesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appModulesProvider).simple, isFalse);
    });

    test(
        'module_simple survives a restart, and turning it off deletes '
        'nothing else', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(appModulesProvider.notifier).set(const AppModules(
          simple: true, places: false, community: CommunityMode.forumsOnly));
      first.dispose();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('module_simple'), isTrue);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(appModulesProvider);
      await Future<void>.delayed(Duration.zero);
      final m = second.read(appModulesProvider);
      expect(m.simple, isTrue);
      expect(m.places, isFalse);
      expect(m.community, CommunityMode.forumsOnly);

      await second
          .read(appModulesProvider.notifier)
          .set(m.copyWith(simple: false));
      expect(prefs.getBool('module_simple'), isFalse);
      final off = second.read(appModulesProvider);
      expect(off.places, isFalse);
      expect(off.community, CommunityMode.forumsOnly);
      expect(off.forums, isTrue);
    });
  });
}
