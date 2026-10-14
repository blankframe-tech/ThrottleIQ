import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';

/// Loads [prefs] into a fresh container and lets `_loadPersisted` settle.
Future<AppAppearance> _restore(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(appearanceProvider);
  await pumpEventQueue();
  return container.read(appearanceProvider);
}

void main() {
  // AppearanceNotifier registers a WidgetsBindingObserver so it can follow the
  // OS light/dark setting (issues §83.9), so these need a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  group('AppearanceNotifier', () {
    test('defaults to Light, the Calming palette', () async {
      final a = await _restore({});
      expect(a, AppAppearance.defaultAppearance);
      expect(AppColorPalette.forBrightness(a.brightness),
          same(AppColorPalette.calmingLight));
    });

    test('setBrightnessMode(dark) switches to Carbon Mono and persists it',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container
          .read(appearanceProvider.notifier)
          .setBrightnessMode(AppBrightnessMode.dark);

      final a = container.read(appearanceProvider);
      expect(a.brightness, Brightness.dark);
      expect(AppColorPalette.forBrightness(a.brightness),
          same(AppColorPalette.carbonMonoDark));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('brightness'), 'dark');
    });

    test('a saved light/dark choice restores', () async {
      expect(
          (await _restore({'brightness': 'dark'})).brightness, Brightness.dark);
      expect((await _restore({'brightness': 'light'})).brightness,
          Brightness.light);
    });
  });

  group('migration from removed themes', () {
    // Riders on one of the 7 color families x 2 shapes keep their brightness,
    // which picks the nearest remaining theme.
    for (final (family, shape, brightness, expected) in [
      ('rain', 'boxy', 'dark', Brightness.dark),
      ('city', 'curvy', 'light', Brightness.light),
      ('race', 'boxy', 'light', Brightness.light),
      ('adv', 'curvy', 'dark', Brightness.dark),
    ]) {
      test('$family/$shape/$brightness → ${expected.name}', () async {
        final a = await _restore({
          'color_mode': family,
          'shape_vibe': shape,
          'brightness': brightness,
        });
        expect(a.brightness, expected);
      });
    }

    test('a rider who only changed color or shape stays light', () async {
      // They saw that family's light variant, since light was the default.
      expect((await _restore({'color_mode': 'sport'})).brightness,
          Brightness.light);
      expect((await _restore({'shape_vibe': 'boxy'})).brightness,
          Brightness.light);
    });

    test('"system" survives the migration', () async {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .platformBrightnessTestValue = Brightness.dark;
      final a = await _restore({'color_mode': 'tour', 'brightness': 'system'});
      expect(a.brightnessMode, AppBrightnessMode.system);
      expect(a.brightness, Brightness.dark);
    });

    group('pre-split single-key skins', () {
      for (final (skin, expected) in [
        ('carbon', Brightness.dark),
        ('nocturne', Brightness.dark),
        ('trailSocial', Brightness.dark),
        ('analystBlue', Brightness.dark),
        ('cuteAnalyst', Brightness.dark),
        ('editorial', Brightness.light),
        ('calming', Brightness.light),
        ('positiveVibes', Brightness.light),
        ('retro', Brightness.light),
        ('genesis', Brightness.light),
      ]) {
        test('"$skin" → ${expected.name}', () async {
          expect((await _restore({'theme_style': skin})).brightness, expected);
        });
      }

      test('a newer key wins over a stale legacy skin', () async {
        // The split scheme was written after theme_style, so it is the
        // rider's latest choice even without a brightness key.
        final a =
            await _restore({'theme_style': 'carbon', 'color_mode': 'rain'});
        expect(a.brightness, Brightness.light);
      });
    });
  });

  group('AppBrightnessMode.system', () {
    test('resolves against the OS and persists as "system"', () async {
      SharedPreferences.setMockInitialValues({});
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .platformBrightnessTestValue = Brightness.dark;

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(appearanceProvider.notifier)
          .setBrightnessMode(AppBrightnessMode.system);

      final appearance = container.read(appearanceProvider);
      expect(appearance.brightnessMode, AppBrightnessMode.system);
      expect(appearance.brightness, Brightness.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('brightness'), 'system');
    });

    test('follows an OS flip while on system, and only then', () async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      SharedPreferences.setMockInitialValues({'brightness': 'system'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appearanceProvider);
      await pumpEventQueue();

      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      expect(container.read(appearanceProvider).brightness, Brightness.dark);

      // An explicit Dark ignores the OS going light.
      await container
          .read(appearanceProvider.notifier)
          .setBrightnessMode(AppBrightnessMode.dark);
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      expect(container.read(appearanceProvider).brightness, Brightness.dark);
    });

    test('an explicit brightness implies the matching mode', () {
      expect(const AppAppearance(brightness: Brightness.dark).brightnessMode,
          AppBrightnessMode.dark);
      expect(const AppAppearance(brightness: Brightness.light).brightnessMode,
          AppBrightnessMode.light);
    });
  });
}
