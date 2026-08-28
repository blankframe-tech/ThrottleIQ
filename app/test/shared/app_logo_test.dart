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
    // The mark is a fixed brand identity now — one dark-only asset,
    // regardless of the appearance the rest of the app is using.
    testWidgets('always renders the dark mark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AppLogo(size: 40)),
      );
      await tester.pump();

      expect(assetNameOf(tester), 'assets/icons/throttleiq-icon-dark.svg');
    });

    testWidgets('renders the dark mark under every appearance', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppLogo(size: 40)),
        ),
      );

      for (final brightness in Brightness.values) {
        await container.read(appearanceProvider.notifier).setBrightness(brightness);
        for (final mode in AppColorMode.values) {
          await container.read(appearanceProvider.notifier).setColorMode(mode);
          await tester.pump();
          expect(
            assetNameOf(tester),
            'assets/icons/throttleiq-icon-dark.svg',
            reason: '$mode/$brightness',
          );
        }
      }
    });
  });
}
