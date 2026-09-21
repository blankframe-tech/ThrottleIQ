import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_context.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The acceptance test for issues §83.9: an appearance change must reach every
/// widget WITHOUT unmounting the app.
///
/// `app.dart` used to key `MaterialApp` on the appearance, because tokens were
/// mutable statics that no widget depended on — the only way to make a static
/// read change was to destroy and rebuild everything, losing scroll offsets,
/// map cameras, half-typed forms and open sheets. Tokens now travel on the
/// theme (`context.palette` / `context.shape`), so the tree is left alone and
/// only dependents rebuild. This mirrors `app.dart`'s wiring — a `MaterialApp`
/// with no key, themed from `appearanceProvider` — around a probe that keeps
/// state, since that state surviving is the property under test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData themeFor(AppAppearance a) => ThemeData(extensions: [
        AppColorPalette.forMode(a.colorMode, a.brightness),
        AppShapeProfile.forVibe(a.shapeVibe),
      ]);

  Widget app(Widget probe) => ProviderScope(
        child: Consumer(builder: (context, ref, _) {
          final appearance = ref.watch(appearanceProvider);
          return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
            // Deliberately no `key: ValueKey(appearance)`.
            theme: themeFor(appearance),
            themeAnimationDuration: Duration.zero,
            home: Scaffold(body: probe),
          );
        }),
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a color change re-themes a live widget and keeps its State',
      (tester) async {
    await tester.pumpWidget(app(const _Probe()));
    await tester.pumpAndSettle();

    final probe = tester.state<_ProbeState>(find.byType(_Probe));
    probe.counter = 7; // stands in for a scroll offset / half-typed form
    final before = tester.widget<Container>(find.byKey(_Probe.swatch)).color;
    expect(before, AppColorPalette.calmingLight.primary);

    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    await container.read(appearanceProvider.notifier).setColorMode(AppColorMode.retro);
    await tester.pumpAndSettle();

    // Re-themed everywhere it reads a token...
    expect(tester.widget<Container>(find.byKey(_Probe.swatch)).color,
        AppColorPalette.retroLight.primary);
    // ...without being remounted: same State object, same in-memory value.
    expect(tester.state<_ProbeState>(find.byType(_Probe)), same(probe));
    expect(probe.counter, 7);
    expect(probe.initCount, 1, reason: 'initState must not run again');
  });

  testWidgets('a shape change re-themes a live widget and keeps its State',
      (tester) async {
    await tester.pumpWidget(app(const _Probe()));
    await tester.pumpAndSettle();

    final probe = tester.state<_ProbeState>(find.byType(_Probe));
    expect(tester.widget<Text>(find.byKey(_Probe.radius)).data,
        '${AppShapeProfile.curvy.radiusMd}');

    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    await container.read(appearanceProvider.notifier).setShapeVibe(AppShapeVibe.boxy);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(_Probe.radius)).data,
        '${AppShapeProfile.boxy.radiusMd}');
    expect(tester.state<_ProbeState>(find.byType(_Probe)), same(probe));
    expect(probe.initCount, 1);
  });

  testWidgets('brightness flips the palette in place too', (tester) async {
    await tester.pumpWidget(app(const _Probe()));
    await tester.pumpAndSettle();
    final probe = tester.state<_ProbeState>(find.byType(_Probe));

    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    await container
        .read(appearanceProvider.notifier)
        .setBrightnessMode(AppBrightnessMode.dark);
    await tester.pumpAndSettle();

    expect(tester.widget<Container>(find.byKey(_Probe.swatch)).color,
        AppColorPalette.calmingDark.primary);
    expect(tester.state<_ProbeState>(find.byType(_Probe)), same(probe));
  });

  testWidgets('a tree with no registered tokens falls back to the default appearance',
      (tester) async {
    // A bare MaterialApp — what most widget tests pump — has no extensions.
    await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: _Probe()));

    expect(tester.widget<Container>(find.byKey(_Probe.swatch)).color,
        AppColorPalette.calmingLight.primary);
    expect(tester.widget<Text>(find.byKey(_Probe.radius)).data,
        '${AppShapeProfile.curvy.radiusMd}');
  });
}

class _Probe extends StatefulWidget {
  const _Probe();

  static const swatch = ValueKey('swatch');
  static const radius = ValueKey('radius');

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int counter = 0;
  int initCount = 0;

  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            key: _Probe.swatch, width: 10, height: 10, color: context.palette.primary),
        Text('${context.shape.radiusMd}', key: _Probe.radius),
      ]);
}
