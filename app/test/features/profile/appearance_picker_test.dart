import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/profile/presentation/widgets/appearance_picker.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The Color control in Settings › Appearance. Tested here rather than
/// through `SettingsScreen`, which can't be pumped without a live Firebase
/// app (its emergency-contacts notifier reaches `FirebaseFirestore.instance`
/// in a field initializer) — which is also why the picker is its own widget.
void main() {
  final theme = ThemeData(splashFactory: InkRipple.splashFactory);

  Widget harness(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ColorModeDropdown()),
        ),
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens to every color mode, each with a name and a blurb',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final mode in AppColorMode.values) {
      expect(find.text(colorModeLabel(l10n, mode)), findsWidgets, reason: '$mode');
      expect(find.text(colorModeDescription(l10n, mode)), findsWidgets,
          reason: '$mode');
    }
  });

  testWidgets('picking a color mode applies and persists it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    expect(container.read(appearanceProvider).colorMode, AppColorMode.commute);

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(colorModeLabel(l10n, AppColorMode.adv)).last);
    await tester.pumpAndSettle();

    expect(container.read(appearanceProvider).colorMode, AppColorMode.adv);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('color_mode'), 'adv');
  });

  testWidgets('the closed field shows the color mode already in effect',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'color_mode': 'race',
      'shape_vibe': 'boxy',
      'brightness': 'light',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appearanceProvider);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(colorModeLabel(l10n, AppColorMode.race)), findsOneWidget);
  });

  testWidgets('rows grow with accessibility text scaling rather than clipping',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final swatches = find.byType(ColorModeSwatch);
    final content = tester.getSize(find
        .descendant(
            of: find
                .ancestor(of: swatches.at(1), matching: find.byType(Row))
                .first,
            matching: find.byType(Column))
        .first);
    final pitch = tester.getTopLeft(swatches.at(2)).dy -
        tester.getTopLeft(swatches.at(1)).dy;
    expect(pitch, greaterThanOrEqualTo(content.height));
    expect(pitch, greaterThanOrEqualTo(48.0));
  });

  testWidgets('each row previews its own palette, at the currently active brightness',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();

    final backgrounds = tester
        .widgetList<ColorModeSwatch>(find.byType(ColorModeSwatch))
        .map((s) => AppColorPalette.forMode(s.mode, s.brightness).background.toARGB32())
        .toSet();
    expect(
      backgrounds.length,
      AppColorMode.values
          .map((m) => AppColorPalette.forMode(m, Brightness.dark).background.toARGB32())
          .toSet()
          .length,
    );
  });

  testWidgets('every row\'s swatch follows the currently active shape vibe',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.curvy);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();

    double swatchRadius(AppColorMode mode) {
      final widget = tester.widget<Container>(find
          .descendant(
              of: find.byWidget(tester
                  .widgetList<ColorModeSwatch>(find.byType(ColorModeSwatch))
                  .firstWhere((s) => s.mode == mode)),
              matching: find.byType(Container))
          .first);
      final decoration = widget.decoration! as BoxDecoration;
      return (decoration.borderRadius! as BorderRadius).topLeft.x;
    }

    final expectedRadius = AppShapeProfile.curvy.radiusLg / 2;
    for (final mode in AppColorMode.values) {
      expect(swatchRadius(mode), expectedRadius, reason: '$mode');
    }
  });

  Widget segmentedHarness(ProviderContainer container) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
              body: SingleChildScrollView(child: ColorModeSegmentedPicker())),
        ),
      );

  testWidgets('ColorModeSegmentedPicker shows all seven ride modes and switches on tap',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(segmentedHarness(container));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(AppColorMode.values, hasLength(7));
    for (final mode in AppColorMode.values) {
      expect(find.text(colorModeLabel(l10n, mode)), findsOneWidget);
      expect(find.text(colorModeDescription(l10n, mode)), findsOneWidget);
    }

    for (final mode in [AppColorMode.race, AppColorMode.city, AppColorMode.rain]) {
      await tester.tap(find.text(colorModeLabel(l10n, mode)));
      await tester.pumpAndSettle();
      expect(container.read(appearanceProvider).colorMode, mode);
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('color_mode'), 'rain');
  });

  testWidgets('ColorModeSegmentedPicker fits a narrow phone at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(segmentedHarness(container));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ColorModeSwatch), findsNWidgets(7));
  });
}
