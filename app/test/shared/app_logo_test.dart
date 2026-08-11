import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/shared/widgets/app_logo.dart';

/// Pulls the asset path out of whatever `SvgPicture.asset` built.
String assetNameOf(WidgetTester tester) {
  final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
  final loader = svg.bytesLoader as SvgAssetLoader;
  return loader.assetName;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppLogo', () {
    testWidgets('renders the dark mark under Carbon Mono', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AppLogo(size: 40)),
        ),
      );
      await tester.pump();

      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-dark.svg');
    });

    // The regression this file exists for: toggling appearance must swap the
    // mark. AppLogo watches themeStyleProvider directly, so a `const`
    // constructor at the call site does not (and must not) prevent it.
    testWidgets('swaps to the light mark when appearance changes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppLogo(size: 40)),
        ),
      );
      await tester.pump();
      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-dark.svg');

      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.editorial);
      await tester.pump();

      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-light.svg');
    });

    // The mark follows the skin's base brightness, not `style == carbonMono`
    // — which was the rule until there was more than one dark skin, and would
    // now hand every new dark skin the light mark.
    testWidgets('every skin gets the mark matching its brightness',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppLogo(size: 40)),
        ),
      );

      for (final style in AppThemeStyle.values) {
        await container.read(themeStyleProvider.notifier).setStyle(style);
        await tester.pump();
        expect(
          assetNameOf(tester),
          AppColorPalette.forStyle(style).isDark
              ? 'assets/icons/throttleiq-icon-dark.svg'
              : 'assets/icons/throttleiq-icon-light.svg',
          reason: '$style',
        );
      }
    });

    testWidgets('swaps back to dark', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppLogo(size: 40)),
        ),
      );
      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.editorial);
      await tester.pump();
      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-light.svg');

      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.carbonMono);
      await tester.pump();

      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-dark.svg');
    });

    // A `const AppLogo(...)` at the call site is how both existing usages are
    // written. Const-ness canonicalizes the *widget*, not the element, so the
    // element still rebuilds on a provider change — pin that, because it's the
    // thing everyone assumes is the bug.
    testWidgets('still swaps when constructed as const', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Column(children: [AppLogo(size: 40)]),
          ),
        ),
      );
      await tester.pump();
      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-dark.svg');

      await container
          .read(themeStyleProvider.notifier)
          .setStyle(AppThemeStyle.editorial);
      await tester.pump();

      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-light.svg');
    });
  });
}
