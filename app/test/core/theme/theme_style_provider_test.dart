import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/constants/app_colors.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';

void main() {
  group('ThemeStyleNotifier', () {
    test('defaults to Carbon Mono and applies its palette to AppColors immediately', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeStyleProvider), AppThemeStyle.carbonMono);
      expect(AppColors.primary, AppColorPalette.carbonMono.primary);
      expect(AppColors.background, AppColorPalette.carbonMono.background);

      await pumpEventQueue();
    });

    test('setStyle(editorial) flips both the provider state and AppColors, and persists it',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(themeStyleProvider.notifier).setStyle(AppThemeStyle.editorial);

      expect(container.read(themeStyleProvider), AppThemeStyle.editorial);
      expect(AppColors.primary, AppColorPalette.editorial.primary);
      expect(AppColors.background, AppColorPalette.editorial.background);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_style'), 'editorial');
    });

    test('setStyle(carbonMono) switches back from Editorial and updates AppColors', () async {
      SharedPreferences.setMockInitialValues({'theme_style': 'editorial'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeStyleProvider); // trigger lazy notifier construction
      await pumpEventQueue();
      expect(container.read(themeStyleProvider), AppThemeStyle.editorial);

      await container.read(themeStyleProvider.notifier).setStyle(AppThemeStyle.carbonMono);

      expect(container.read(themeStyleProvider), AppThemeStyle.carbonMono);
      expect(AppColors.primary, AppColorPalette.carbonMono.primary);
      expect(AppColors.background, AppColorPalette.carbonMono.background);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_style'), 'carbon');
    });

    test('a persisted "editorial" preference is restored on the next app start', () async {
      SharedPreferences.setMockInitialValues({'theme_style': 'editorial'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Providers are lazy: reading it is what constructs the notifier (and
      // seeds Carbon Mono synchronously). Only then does its persisted-choice
      // load kick off asynchronously — pump the event queue for that to land.
      container.read(themeStyleProvider);
      await pumpEventQueue();

      expect(container.read(themeStyleProvider), AppThemeStyle.editorial);
      expect(AppColors.primary, AppColorPalette.editorial.primary);
    });

    test('a skin persists under its enum name and restores from it', () async {
      // Skins added after the original two round-trip through
      // `AppThemeStyle.name`; only Carbon Mono and Editorial keep the two
      // hand-written legacy spellings asserted above.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.analystBlue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_style'), 'analystBlue');
      expect(AppColors.primary, AppColorPalette.analystBlue.primary);

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      restored.read(themeStyleProvider);
      await pumpEventQueue();
      expect(restored.read(themeStyleProvider), AppThemeStyle.analystBlue);
    });

    test('every skin survives a persist/restore round trip', () async {
      // The encode/decode pair is hand-written (legacy spellings on one side,
      // enum names on the other), which is exactly the kind of mapping that
      // silently loses whichever member nobody thought to try.
      for (final style in AppThemeStyle.values) {
        SharedPreferences.setMockInitialValues({});
        final writer = ProviderContainer();
        await pumpEventQueue();
        await writer.read(themeStyleProvider.notifier).setStyle(style);
        writer.dispose();

        final reader = ProviderContainer();
        reader.read(themeStyleProvider);
        await pumpEventQueue();
        expect(reader.read(themeStyleProvider), style, reason: '$style');
        reader.dispose();
      }
    });

    test('an unrecognised persisted value falls back to Carbon Mono', () async {
      // e.g. a skin removed since it was written, or prefs carried back to an
      // older build. The rider gets the default, not a crash.
      SharedPreferences.setMockInitialValues({'theme_style': 'vaporwave'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeStyleProvider);
      await pumpEventQueue();

      expect(container.read(themeStyleProvider), AppThemeStyle.carbonMono);
      expect(AppColors.primary, AppColorPalette.carbonMono.primary);
    });

    test('setStyle is a no-op when already on the requested style', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(themeStyleProvider.notifier).setStyle(AppThemeStyle.carbonMono);

      expect(container.read(themeStyleProvider), AppThemeStyle.carbonMono);
      final prefs = await SharedPreferences.getInstance();
      // Never persisted anything, since setStyle returned early.
      expect(prefs.getString('theme_style'), isNull);
    });
  });
}
