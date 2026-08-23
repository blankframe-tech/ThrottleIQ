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
  // Material 3's default splash is InkSparkle, which compiles a fragment
  // shader the test engine's shader bundle can't decode — tapping anything
  // throws before the tap is delivered. Nothing to do with this widget, so
  // swap in the non-shader ripple for the harness only.
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
    expect(container.read(appearanceProvider).colorMode, AppColorMode.carbonMono);

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // `.last` because the menu route reuses the same label text that the
    // closed field is still rendering underneath it.
    await tester.tap(find.text(colorModeLabel(l10n, AppColorMode.analystBlue)).last);
    await tester.pumpAndSettle();

    expect(container.read(appearanceProvider).colorMode, AppColorMode.analystBlue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('color_mode'), 'analystBlue');
  });

  testWidgets('the closed field shows the color mode already in effect',
      (tester) async {
    // A rider who has been on Retro since last launch should open Settings
    // and see Retro, not the default.
    SharedPreferences.setMockInitialValues({
      'color_mode': 'retro',
      'shape_vibe': 'boxy',
      'brightness': 'light',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appearanceProvider);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(colorModeLabel(l10n, AppColorMode.retro)), findsOneWidget);
  });

  testWidgets('rows grow with accessibility text scaling rather than clipping',
      (tester) async {
    // Two-line rows in a menu are the shape that clips under large text, and
    // the device this project is tested on already runs at textScaler 1.1176
    // with bold text — so the 1.0x every other test here uses is not the
    // configuration that ships.
    //
    // Scale via platformDispatcher, NOT by wrapping the subject in a
    // MediaQuery: the dropdown menu opens as its own route above `home`, so
    // an inner MediaQuery never reaches it and the menu renders unscaled —
    // a test written that way passes at any "scale" while measuring nothing.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppColorMode>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The row's on-screen pitch must cover its content, or the second line is
    // sitting under the next row.
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
    // …and never below the 48 dp minimum touch target at any scale.
    expect(pitch, greaterThanOrEqualTo(48.0));
  });

  testWidgets('each row previews its own palette, at the currently active brightness',
      (tester) async {
    // The swatch is what makes seven names choosable. If every row painted
    // the same background, the control would be a list of words.
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
    // Every distinct color mode's background is represented — i.e. the
    // swatches vary per row rather than all rendering the same palette.
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
    // Shape is no longer part of a color mode's identity — every row must
    // reflect whichever AppShapeVibe the rider currently has selected, and
    // all of them together, since it's one global choice, not a per-row one.
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
}
