import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/features/profile/presentation/screens/advanced_settings_screen.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_bike_screen.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_home_screen.dart';
import 'package:throttleiq/features/simple/presentation/screens/simple_rides_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// Simple mode hides Profile, so every Simple tab carries the gear: the rider
/// can always get back to the switch and turn Simple off (#240 review).
void main() {
  final en = AppLocalizationsEn();
  setUp(() => SharedPreferences.setMockInitialValues({'module_simple': true}));

  Future<ProviderContainer> pump(WidgetTester tester, String start) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appModulesProvider); // starts the prefs load
    final router = GoRouter(initialLocation: start, routes: [
      GoRoute(
          path: '/home/simple', builder: (_, __) => const SimpleHomeScreen()),
      GoRoute(
          path: '/home/simple-rides',
          builder: (_, __) => const SimpleRidesScreen()),
      GoRoute(
          path: '/home/simple-bike',
          builder: (_, __) => const SimpleBikeScreen()),
      // Settings links to Advanced (settings_screen.dart); the switch is there.
      GoRoute(
          path: '/settings',
          builder: (_, __) => const AdvancedSettingsScreen()),
      GoRoute(
          path: '/home/record',
          builder: (_, __) => const Scaffold(body: Text('FULL'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  for (final tab in [
    '/home/simple',
    '/home/simple-rides',
    '/home/simple-bike'
  ]) {
    testWidgets('$tab has a labelled 48dp gear to Settings', (tester) async {
      await pump(tester, tab);
      final gear = find.byTooltip(en.settingsTitle);
      expect(gear, findsOneWidget);
      final size =
          tester.getSize(find.byKey(const Key('simple_settings_button')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(gear);
      await tester.pumpAndSettle();
      expect(find.byType(AdvancedSettingsScreen), findsOneWidget);
    });
  }

  testWidgets('Simple on → gear → turn Simple off → the full app is back',
      (tester) async {
    final container = await pump(tester, '/home/simple');
    expect(container.read(appModulesProvider).simple, isTrue);

    await tester.tap(find.byTooltip(en.settingsTitle));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('simple_mode_switch')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('simple_mode_switch')),
        matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(container.read(appModulesProvider).simple, isFalse);
    expect(find.text('FULL'), findsOneWidget);
  });
}
