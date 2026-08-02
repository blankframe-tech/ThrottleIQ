import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/i18n/locale_provider.dart';

void main() {
  group('LocaleNotifier', () {
    test('defaults to following the system when nothing is persisted',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(localeProvider), AppLocale.system);
      // null tells MaterialApp to resolve against the device locale.
      expect(container.read(appLocaleProvider), isNull);

      await pumpEventQueue();
      expect(container.read(localeProvider), AppLocale.system);
    });

    test('setLocale(bangla) flips the state and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(localeProvider.notifier).setLocale(AppLocale.bangla);

      expect(container.read(localeProvider), AppLocale.bangla);
      expect(container.read(appLocaleProvider), const Locale('bn'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'bn');
    });

    test('setLocale(english) persists a pin that is distinct from system',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(localeProvider.notifier).setLocale(AppLocale.english);

      expect(container.read(localeProvider), AppLocale.english);
      // Pinned English is NOT the same as "follow the phone": it must resolve
      // to a concrete Locale, otherwise a Bangla handset would override it.
      expect(container.read(appLocaleProvider), const Locale('en'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en');
    });

    test('setLocale(system) clears a previous pin back to null', () async {
      SharedPreferences.setMockInitialValues({'locale': 'bn'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeProvider);
      await pumpEventQueue();
      expect(container.read(localeProvider), AppLocale.bangla);

      await container.read(localeProvider.notifier).setLocale(AppLocale.system);

      expect(container.read(localeProvider), AppLocale.system);
      expect(container.read(appLocaleProvider), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'system');
    });

    test('a persisted "bn" preference is restored on the next app start',
        () async {
      SharedPreferences.setMockInitialValues({'locale': 'bn'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Providers are lazy: reading it is what constructs the notifier (which
      // seeds `system` synchronously). Only then does the persisted-choice
      // load kick off asynchronously — pump the event queue for that to land.
      container.read(localeProvider);
      await pumpEventQueue();

      expect(container.read(localeProvider), AppLocale.bangla);
      expect(container.read(appLocaleProvider), const Locale('bn'));
    });

    test('an unrecognised persisted value falls back to system, not English',
        () async {
      // e.g. a future build persisted 'hi' and the rider downgraded.
      SharedPreferences.setMockInitialValues({'locale': 'hi'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider);
      await pumpEventQueue();

      expect(container.read(localeProvider), AppLocale.system);
    });

    test('setLocale is a no-op when already on the requested locale', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(localeProvider.notifier).setLocale(AppLocale.system);

      expect(container.read(localeProvider), AppLocale.system);
      final prefs = await SharedPreferences.getInstance();
      // Never persisted anything, since setLocale returned early.
      expect(prefs.getString('locale'), isNull);
    });

    test(
        'disposing the container mid-load does not throw (the mounted guard)',
        () async {
      // The regression this guards: SharedPreferences.getInstance() is async,
      // so a container torn down between construction and the await resolving
      // would otherwise have the notifier assign `state` after dispose, which
      // StateNotifier turns into a "Bad state: Tried to use ... after dispose".
      SharedPreferences.setMockInitialValues({'locale': 'bn'});
      final container = ProviderContainer();

      container.read(localeProvider); // constructs, starts the async load
      container.dispose(); // …and tear it down before the load lands

      // Pumping is where the post-await continuation runs. No throw = guarded.
      await expectLater(pumpEventQueue(), completes);
    });
  });

  group('AppLocale.toLocale', () {
    test('maps every case, with system meaning "defer to the platform"', () {
      expect(AppLocale.system.toLocale, isNull);
      expect(AppLocale.english.toLocale, const Locale('en'));
      expect(AppLocale.bangla.toLocale, const Locale('bn'));
    });
  });
}
