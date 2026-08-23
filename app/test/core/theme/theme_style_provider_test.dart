import 'package:flutter/material.dart';
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
  group('AppearanceNotifier', () {
    test('defaults to Carbon Mono/Boxy/Dark and applies it to AppColors immediately', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appearanceProvider), AppAppearance.defaultAppearance);
      expect(AppColors.primary, AppColorPalette.carbonMonoDark.primary);
      expect(AppColors.background, AppColorPalette.carbonMonoDark.background);

      await pumpEventQueue();
    });

    test('setColorMode(editorial) flips the provider state and AppColors, and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(appearanceProvider.notifier).setColorMode(AppColorMode.editorial);

      expect(container.read(appearanceProvider).colorMode, AppColorMode.editorial);
      // Brightness/vibe are untouched by a color-only change.
      expect(container.read(appearanceProvider).brightness, Brightness.dark);
      expect(AppColors.primary, AppColorPalette.editorialDark.primary);
      expect(AppColors.background, AppColorPalette.editorialDark.background);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('color_mode'), 'editorial');
    });

    test('setBrightness(light) flips brightness only, and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(appearanceProvider.notifier).setBrightness(Brightness.light);

      expect(container.read(appearanceProvider).colorMode, AppColorMode.carbonMono);
      expect(container.read(appearanceProvider).brightness, Brightness.light);
      expect(AppColors.background, AppColorPalette.carbonMonoLight.background);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('brightness'), 'light');
    });

    test('setShapeVibe(curvy) flips shape only, applies it to AppDimensions, and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.curvy);

      expect(container.read(appearanceProvider).colorMode, AppColorMode.carbonMono);
      expect(container.read(appearanceProvider).shapeVibe, AppShapeVibe.curvy);
      expect(AppDimensions.shape, same(AppShapeProfile.curvy));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('shape_vibe'), 'curvy');
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
    });

    test('the three axes persist and restore independently', () async {
      SharedPreferences.setMockInitialValues({});
      final writer = ProviderContainer();
      await pumpEventQueue();
      await writer.read(appearanceProvider.notifier).setColorMode(AppColorMode.analystBlue);
      await writer.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.curvy);
      await writer.read(appearanceProvider.notifier).setBrightness(Brightness.light);
      writer.dispose();

      final reader = ProviderContainer();
      addTearDown(reader.dispose);
      reader.read(appearanceProvider);
      await pumpEventQueue();

      final restored = reader.read(appearanceProvider);
      expect(restored.colorMode, AppColorMode.analystBlue);
      expect(restored.shapeVibe, AppShapeVibe.curvy);
      expect(restored.brightness, Brightness.light);
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
    });

    test('every color mode persists under its enum name and restores', () async {
      for (final mode in AppColorMode.values) {
        SharedPreferences.setMockInitialValues({});
        final writer = ProviderContainer();
        await pumpEventQueue();
        // setColorMode is a no-op (and so persists nothing) when already on
        // the requested mode — real for the default, Carbon Mono, so detour
        // through a different mode first to force an actual transition.
        final detour =
            mode == AppColorMode.retro ? AppColorMode.editorial : AppColorMode.retro;
        await writer.read(appearanceProvider.notifier).setColorMode(detour);
        await writer.read(appearanceProvider.notifier).setColorMode(mode);
        writer.dispose();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('color_mode'), mode.name, reason: '$mode');

        final reader = ProviderContainer();
        reader.read(appearanceProvider);
        await pumpEventQueue();
        expect(reader.read(appearanceProvider).colorMode, mode, reason: '$mode');
        reader.dispose();
      }
    });

    test('an unrecognised persisted color_mode falls back to the default appearance', () async {
      // e.g. a mode removed since it was written (positiveVibes/genesis/
      // cuteAnalyst), or prefs carried back to an older build. Since all
      // three new keys must decode successfully to skip the legacy path,
      // one bad key with no legacy value to fall back to just leaves the
      // default in place — not a crash, and not a half-applied appearance.
      SharedPreferences.setMockInitialValues({
        'color_mode': 'vaporwave',
        'shape_vibe': 'boxy',
        'brightness': 'dark',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appearanceProvider);
      await pumpEventQueue();

      expect(container.read(appearanceProvider), AppAppearance.defaultAppearance);
      expect(AppColors.primary, AppColorPalette.carbonMonoDark.primary);
    });

    group('legacy single-key migration', () {
      // Riders who picked a skin before Vibe/Brightness/Color became three
      // separate choices have one flat 'theme_style' value on disk. It must
      // decode to the equivalent triple exactly once, including the three
      // color modes that no longer exist as standalone options.
      const cases = <String, AppAppearance>{
        'carbon': AppAppearance(
            colorMode: AppColorMode.carbonMono,
            shapeVibe: AppShapeVibe.boxy,
            brightness: Brightness.dark),
        'editorial': AppAppearance(
            colorMode: AppColorMode.editorial,
            shapeVibe: AppShapeVibe.boxy,
            brightness: Brightness.light),
        'trailSocial': AppAppearance(
            colorMode: AppColorMode.trailSocial,
            shapeVibe: AppShapeVibe.curvy,
            brightness: Brightness.dark),
        'retro': AppAppearance(
            colorMode: AppColorMode.retro,
            shapeVibe: AppShapeVibe.boxy,
            brightness: Brightness.light),
        // Dropped modes map to their closest surviving equivalent.
        'positiveVibes': AppAppearance(
            colorMode: AppColorMode.calming,
            shapeVibe: AppShapeVibe.curvy,
            brightness: Brightness.light),
        'genesis': AppAppearance.defaultAppearance,
        // Cute Analyst was always exactly Analyst Blue's palette + rounded
        // shape, so this migration is exact, not an approximation.
        'cuteAnalyst': AppAppearance(
            colorMode: AppColorMode.analystBlue,
            shapeVibe: AppShapeVibe.curvy,
            brightness: Brightness.dark),
      };

      for (final entry in cases.entries) {
        test('"${entry.key}" migrates to ${entry.value.colorMode}/'
            '${entry.value.shapeVibe}/${entry.value.brightness}', () async {
          SharedPreferences.setMockInitialValues({'theme_style': entry.key});
          final container = ProviderContainer();
          addTearDown(container.dispose);
          container.read(appearanceProvider);
          await pumpEventQueue();

          expect(container.read(appearanceProvider), entry.value);
          addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
        });
      }
    });

    test('an appearance applies its shape profile alongside its palette', () async {
      // _applyTokens pushes color, shape and type together on purpose. The
      // failure this guards is a half-applied appearance — the new palette
      // with the previous vibe's corner radius still in place, which looks
      // like a rendering bug rather than a settings bug.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      expect(container.read(appearanceProvider), AppAppearance.defaultAppearance);
      expect(AppDimensions.shape, same(AppShapeProfile.boxy));

      await container.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.curvy);
      expect(AppDimensions.shape, same(AppShapeProfile.curvy));
      expect(AppDimensions.radiusMd, AppShapeProfile.curvy.radiusMd);

      // ...and switching back must take the rounded corners with it.
      await container.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.boxy);
      expect(AppDimensions.shape, same(AppShapeProfile.boxy));
      expect(AppDimensions.radiusMd, AppShapeProfile.boxy.radiusMd);
    });

    test('Retro applies mono type independent of vibe/brightness', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(appearanceProvider.notifier).setColorMode(AppColorMode.retro);
      expect(AppTypography.isMono, isTrue);
      // Brightness is still the default (dark) at this point.
      expect(AppColors.border, AppColorPalette.retroDark.ink);

      await container.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.curvy);
      expect(AppTypography.isMono, isTrue); // unchanged by the vibe switch
      expect(AppDimensions.radiusXl, AppShapeProfile.curvy.radiusXl);

      await container.read(appearanceProvider.notifier).setColorMode(AppColorMode.carbonMono);
      expect(AppTypography.isMono, isFalse);
      addTearDown(() => AppDimensions.apply(AppShapeProfile.boxy));
    });

    test('setColorMode is a no-op when already on the requested mode', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(appearanceProvider.notifier).setColorMode(AppColorMode.carbonMono);

      expect(container.read(appearanceProvider), AppAppearance.defaultAppearance);
      final prefs = await SharedPreferences.getInstance();
      // Never persisted anything, since setColorMode returned early.
      expect(prefs.getString('color_mode'), isNull);
    });
  });
}
