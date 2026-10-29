import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/indriyo/presentation/providers/indriyo_provider.dart';
import 'package:throttleiq/features/profile/presentation/screens/advanced_settings_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Settings → Advanced → Indriyo: pairing is a saved setting, not a build flag.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdvancedSettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('pairing fields show only once Indriyo is on, and it is saved',
      (tester) async {
    final container = await pump(tester);
    expect(find.byKey(const Key('indriyo_stream_url')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('indriyo_enable_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const Key('indriyo_enable_switch')),
        matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(container.read(indriyoSettingsProvider).enabled, isTrue);
    expect(find.byKey(const Key('indriyo_stream_url')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('indriyo_enabled'), isTrue);
  });

  testWidgets('a bad stream address is rejected without testing it',
      (tester) async {
    SharedPreferences.setMockInitialValues({'indriyo_enabled': true});
    final container = await pump(tester);

    await tester.enterText(
        find.byKey(const Key('indriyo_stream_url')), 'not a url');
    await tester
        .ensureVisible(find.byKey(const Key('indriyo_test_connection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('indriyo_test_connection')));
    await tester.pumpAndSettle();

    expect(find.text('Enter an address that starts with http:// or https://'),
        findsOneWidget);
    expect(container.read(indriyoSettingsProvider).streamUrl,
        kIndriyoDefaultStreamUrl);
  });

  test('saved settings load; the HUD and demo mode start off', () async {
    SharedPreferences.setMockInitialValues({
      'indriyo_enabled': true,
      'indriyo_stream_url': 'http://10.0.0.5:81/stream',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(indriyoSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    final s = container.read(indriyoSettingsProvider);
    expect(s.enabled, isTrue);
    expect(s.streamUrl, 'http://10.0.0.5:81/stream');
    expect(s.isHudVisible, isFalse);
    expect(s.isSimulationMode, isFalse);
  });
}
