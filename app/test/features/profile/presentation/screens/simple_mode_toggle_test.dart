import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/app_modules.dart';
import 'package:throttleiq/features/profile/presentation/screens/advanced_settings_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// Settings → Advanced → Your ThrottleIQ → Simple mode (#240).
void main() {
  final en = AppLocalizationsEn();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, GoRouter)> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/settings/advanced', routes: [
      GoRoute(
          path: '/settings/advanced',
          builder: (_, __) => const AdvancedSettingsScreen()),
      GoRoute(
          path: '/home/simple',
          builder: (_, __) => const Scaffold(body: Text('SIMPLE'))),
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
    return (container, router);
  }

  Finder simpleSwitch() => find.descendant(
      of: find.byKey(const Key('simple_mode_switch')),
      matching: find.byType(Switch));

  void expectNoModuleWarnings() {
    for (final title in [
      en.communityOffWarningTitle,
      en.communityForumsOnlyWarningTitle,
      en.placesOffWarningTitle,
      en.rideTrackingOffWarningTitle,
    ]) {
      expect(find.text(title), findsNothing, reason: title);
    }
  }

  testWidgets('turning Simple on asks once, saves module_simple, goes home',
      (tester) async {
    final (container, _) = await pump(tester);
    expect(find.text(en.simpleModeTitle), findsOneWidget);

    await tester.tap(simpleSwitch());
    await tester.pumpAndSettle();
    expect(find.text(en.simpleModeOnTitle), findsOneWidget);
    expectNoModuleWarnings();

    await tester.tap(find.text(en.simpleModeOnAction));
    await tester.pumpAndSettle();

    expect(container.read(appModulesProvider).simple, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('module_simple'), isTrue);
    expect(find.text('SIMPLE'), findsOneWidget);
    expect(find.text(en.modulesUpdatedSnack), findsOneWidget);
    expectNoModuleWarnings();
    // Nothing else changed.
    final m = container.read(appModulesProvider);
    expect(m.community, CommunityMode.full);
    expect(m.places, isTrue);
    expect(m.rideTracking, isTrue);
  });

  testWidgets('cancel leaves Simple off', (tester) async {
    final (container, _) = await pump(tester);
    await tester.tap(simpleSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.cancelAction));
    await tester.pumpAndSettle();

    expect(container.read(appModulesProvider).simple, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('module_simple'), isNull);
    expect(find.text('SIMPLE'), findsNothing);
  });

  testWidgets('turning Simple off asks nothing and goes to the full home',
      (tester) async {
    SharedPreferences.setMockInitialValues({'module_simple': true});
    final (container, _) = await pump(tester);
    expect(container.read(appModulesProvider).simple, isTrue);
    // Simple forces community off, so its picker is not offered meanwhile.
    expect(find.text(en.simpleModeCommunityHidden), findsOneWidget);
    expect(find.text(en.communityOffLabel), findsNothing);

    await tester.tap(simpleSwitch());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expectNoModuleWarnings();
    expect(container.read(appModulesProvider).simple, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('module_simple'), isFalse);
    expect(find.text('FULL'), findsOneWidget);
    expect(find.text(en.simpleModeOffSnack), findsOneWidget);
  });

  testWidgets('the community picker shows while Simple is off', (tester) async {
    await pump(tester);
    expect(find.text(en.communityOffLabel), findsOneWidget);
    expect(find.text(en.simpleModeCommunityHidden), findsNothing);
  });
}
