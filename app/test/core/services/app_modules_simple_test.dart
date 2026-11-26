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

  test('people follows the community choice in both modes', () {
    for (final simpleOn in [false, true]) {
      expect(AppModules(simple: simpleOn).people, isTrue);
      for (final mode in [CommunityMode.forumsOnly, CommunityMode.off]) {
        expect(AppModules(community: mode, simple: simpleOn).people, isFalse,
            reason: '${mode.name} simple=$simpleOn');
      }
    }
    // Full mode: people is exactly social, so nothing there changes.
    for (final mode in CommunityMode.values) {
      final m = AppModules(community: mode);
      expect(m.people, m.social, reason: mode.name);
    }
  });

  group('tabs and home', () {
    test("four tabs in the full bar's order: People, Home, Rides, Bike", () {
      expect(simple.tabs, [
        '/home/simple-people',
        '/home/simple',
        '/home/simple-rides',
        '/home/simple-bike',
      ]);
      // Social leads the full bar too; Home stays the landing tab.
      expect(const AppModules().tabs.first, '/home/social');
      expect(simple.home, '/home/simple');
    });

    test('no Rides tab with ride tracking off', () {
      expect(simpleNoTracking.tabs,
          ['/home/simple-people', '/home/simple', '/home/simple-bike']);
      expect(simpleNoTracking.home, '/home/simple');
    });

    test('no People tab unless community is full; places changes nothing', () {
      for (final mode in [CommunityMode.forumsOnly, CommunityMode.off]) {
        expect(AppModules(simple: true, community: mode).tabs,
            ['/home/simple', '/home/simple-rides', '/home/simple-bike'],
            reason: mode.name);
      }
      expect(const AppModules(simple: true, places: false).tabs, simple.tabs);
    });
  });

  group('redirectFor in simple mode', () {
    test('the maintenance tab root goes to the Bike tab', () {
      expect(simple.redirectFor('/home/maintenance'), '/home/simple-bike');
      expect(
          simple.redirectFor('/home/maintenance?bikeId=b1', simpleBikeId: 'b1'),
          '/home/simple-bike');
    });

    test("another bike's maintenance link keeps its own page", () {
      // A two-bike rider's alert for bike b2 must not show b1's checklist.
      expect(
          simple.redirectFor('/home/maintenance?bikeId=b2', simpleBikeId: 'b1'),
          isNull);
      // Garage still loading: show the bike the link asked for.
      expect(simple.redirectFor('/home/maintenance?bikeId=b2'), isNull);
    });

    test('hidden areas land on the simple home', () {
      for (final loc in [
        '/home/record',
        '/home/stats',
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
        // The existing social and forum rules, through the getters:
        // forums, chat, notifications, group rides and the ride feed.
        '/forums/f1',
        '/forums/create',
        '/chats',
        '/chats/c1',
        '/notifications',
        '/group-ride/g1',
        '/rides/shared/r1',
        '/rides/mine',
        '/ride/share/r1',
      ]) {
        expect(simple.redirectFor(loc), '/home/simple', reason: loc);
      }
    });

    test('People: riders, their profiles and the follow QR stay', () {
      for (final loc in [
        '/home/simple-people',
        '/people/all',
        '/profile/uid1',
        '/profile/qr',
        '/profile/scan',
      ]) {
        expect(simple.redirectFor(loc), isNull, reason: loc);
      }
      // A follow link lands on Social's People tab: Simple's instead.
      expect(simple.redirectFor('/home/social'), '/home/simple-people');
      expect(
          simple.redirectFor('/home/social?tab=people'), '/home/simple-people');
    });

    test('with community not full, People is gone too', () {
      for (final mode in [CommunityMode.forumsOnly, CommunityMode.off]) {
        final m = AppModules(simple: true, community: mode);
        for (final loc in [
          '/home/simple-people',
          '/home/social',
          '/people/all',
          '/profile/uid1',
          '/profile/qr',
        ]) {
          expect(m.redirectFor(loc), '/home/simple',
              reason: '${mode.name} $loc');
        }
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
        '/home/simple-people',
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
      expect(shellTabIndexForLocation('/home/simple-people', simple), 0);
      expect(shellTabIndexForLocation('/home/simple', simple), 1);
      expect(shellTabIndexForLocation('/home/simple-rides/r1', simple), 2);
      expect(shellTabIndexForLocation('/home/simple-bike', simple), 3);
      expect(
          shellTabIndexForLocation('/home/simple-bike', simpleNoTracking), 2);
    });

    test('maintenance and bike screens highlight the Bike tab', () {
      for (final loc in [
        '/home/maintenance',
        '/home/maintenance/fuel/add?bikeId=b1',
        '/home/profile/add',
        '/home/profile/b1/edit',
      ]) {
        expect(shellTabIndexForLocation(loc, simple), 3, reason: loc);
        expect(shellTabIndexForLocation(loc, simpleNoTracking), 2, reason: loc);
      }
    });

    test('unknown falls back to the simple home', () {
      expect(shellTabIndexForLocation('/nowhere', simple), 1);
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
