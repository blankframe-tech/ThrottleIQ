import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/profile/presentation/widgets/skin_dropdown.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The Appearance control in Settings. Tested here rather than through
/// `SettingsScreen`, which can't be pumped without a live Firebase app (its
/// emergency-contacts notifier reaches `FirebaseFirestore.instance` in a field
/// initializer) — which is also why the picker is its own widget.
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
          home: const Scaffold(body: SkinDropdown()),
        ),
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens to every skin, each with a name and a blurb',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeStyle>));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final style in AppThemeStyle.values) {
      expect(find.text(skinLabel(l10n, style)), findsWidgets, reason: '$style');
      expect(find.text(skinDescription(l10n, style)), findsWidgets,
          reason: '$style');
    }
  });

  testWidgets('picking a skin applies and persists it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    expect(container.read(themeStyleProvider), AppThemeStyle.carbonMono);

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeStyle>));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // `.last` because the menu route reuses the same label text that the
    // closed field is still rendering underneath it.
    await tester.tap(find.text(skinLabel(l10n, AppThemeStyle.genesis)).last);
    await tester.pumpAndSettle();

    expect(container.read(themeStyleProvider), AppThemeStyle.genesis);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_style'), 'genesis');
  });

  testWidgets('the closed field shows the skin already in effect',
      (tester) async {
    // A rider who has been on Retro since last launch should open Settings and
    // see Retro, not the default.
    SharedPreferences.setMockInitialValues({'theme_style': 'retro'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(themeStyleProvider);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(skinLabel(l10n, AppThemeStyle.retro)), findsOneWidget);
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

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeStyle>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The row's on-screen pitch must cover its content, or the second line is
    // sitting under the next row.
    final swatches = find.byType(SkinSwatch);
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

  testWidgets('each row previews its own palette, not the applied one',
      (tester) async {
    // The swatch is what makes nine names choosable. If every row painted the
    // current skin's colors, the control would be a list of words.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeStyle>));
    await tester.pumpAndSettle();

    final backgrounds = tester
        .widgetList<SkinSwatch>(find.byType(SkinSwatch))
        .map((s) => AppColorPalette.forStyle(s.style).background.toARGB32())
        .toSet();
    // Every distinct skin background is represented — i.e. the swatches vary
    // per row rather than all rendering the applied palette.
    expect(
      backgrounds.length,
      AppThemeStyle.values
          .map((s) => AppColorPalette.forStyle(s).background.toARGB32())
          .toSet()
          .length,
    );
  });

  testWidgets('each row previews its own corner shape, not the applied one',
      (tester) async {
    // Shape is part of what a skin is (rounded / boxy / Retro's square), so the
    // picker has to show it for the same reason it shows the colors: otherwise a
    // rider has to apply all nine to find out which ones are round.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeStyle>));
    await tester.pumpAndSettle();

    double swatchRadius(AppThemeStyle style) {
      final container = tester.widget<Container>(find
          .descendant(
              of: find.byWidget(tester
                  .widgetList<SkinSwatch>(find.byType(SkinSwatch))
                  .firstWhere((s) => s.style == style)),
              matching: find.byType(Container))
          .first);
      final decoration = container.decoration! as BoxDecoration;
      return (decoration.borderRadius! as BorderRadius).topLeft.x;
    }

    // Carbon Mono is boxy, Positive Vibes is rounded, Retro is square — three
    // visibly different swatches while the applied skin is Carbon Mono
    // throughout.
    expect(swatchRadius(AppThemeStyle.retro), 0);
    expect(swatchRadius(AppThemeStyle.positiveVibes),
        greaterThan(swatchRadius(AppThemeStyle.carbonMono)));
  });
}
