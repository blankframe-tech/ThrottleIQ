import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/constants/app_colors.dart';
import 'package:throttleiq/core/constants/app_dimensions.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/app_typography.dart';
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

    test('a skin applies its shape profile alongside its palette', () async {
      // _applyTokens pushes color, shape and type together on purpose. The
      // failure this guards is a half-applied skin — the new palette with the
      // previous skin's corner radius still in place, which looks like a
      // rendering bug rather than a settings bug.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      // Carbon Mono, the default, is boxy. Reading the provider is what
      // constructs the notifier (and so applies the default tokens) — asserting
      // on the facade before that would just be reading whatever the previous
      // test left in these statics.
      expect(container.read(themeStyleProvider), AppThemeStyle.carbonMono);
      expect(AppDimensions.shape, same(AppShapeProfile.boxy));
      expect(AppDimensions.radiusMd, AppShapeProfile.boxy.radiusMd);

      // Positive Vibes is one of the rounded directions.
      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.positiveVibes);
      expect(AppDimensions.shape, same(AppShapeProfile.rounded));
      expect(AppDimensions.radiusMd, AppShapeProfile.rounded.radiusMd);
      expect(AppColors.primary, AppColorPalette.positiveVibes.primary);

      // ...and switching away from it must take the rounded corners with it.
      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.analystBlue);
      expect(AppDimensions.shape, same(AppShapeProfile.boxy));
      expect(AppDimensions.radiusMd, AppShapeProfile.boxy.radiusMd);
    });

    test('Retro applies square corners and mono type together', () async {
      // Retro is the only skin that moves all three axes at once, so it is the
      // one that catches a facade that was forgotten in _applyTokens.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.retro);

      expect(AppDimensions.shape, same(AppShapeProfile.terminal));
      expect(AppDimensions.radiusXl, 0);
      expect(AppDimensions.outlineWidth, 2);
      expect(AppTypography.isMono, isTrue);
      expect(AppColors.border, AppColorPalette.retro.ink);

      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.carbonMono);
      expect(AppDimensions.radiusXl, AppShapeProfile.boxy.radiusXl);
      expect(AppTypography.isMono, isFalse);
    });

    test('a persisted skin restores its shape, not just its palette', () async {
      SharedPreferences.setMockInitialValues({'theme_style': 'calming'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeStyleProvider);
      await pumpEventQueue();

      expect(container.read(themeStyleProvider), AppThemeStyle.calming);
      expect(AppDimensions.shape, same(AppShapeProfile.rounded));
    });

    test('every skin\'s applied shape matches its declared profile', () async {
      for (final style in AppThemeStyle.values) {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        await pumpEventQueue();
        await container.read(themeStyleProvider.notifier).setStyle(style);
        expect(AppDimensions.shape, same(AppShapeProfile.forStyle(style)),
            reason: '$style');
        container.dispose();
      }
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
