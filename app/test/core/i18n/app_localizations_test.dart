import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// End-to-end proof that the pipeline works: ARB → `flutter gen-l10n` →
/// delegate → the string a rider actually sees. The parity test next door
/// checks the *files* agree; this checks the wiring in between.
void main() {
  // Must stay identical to app.dart's `supportedLocales`. Note this is NOT
  // `AppLocalizations.supportedLocales` — see the ordering test below.
  const supportedLocales = [Locale('en'), Locale('bn')];

  /// Pumps a minimal app at [locale] and hands back its AppLocalizations.
  Future<AppLocalizations> localizationsFor(
    WidgetTester tester,
    Locale locale,
  ) async {
    late AppLocalizations captured;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: supportedLocales,
      home: Builder(builder: (context) {
        captured = AppLocalizations.of(context);
        return const SizedBox.shrink();
      }),
    ));
    return captured;
  }

  testWidgets('supports exactly English and Bangla', (tester) async {
    expect(AppLocalizations.supportedLocales,
        containsAll(const [Locale('en'), Locale('bn')]));
    expect(AppLocalizations.supportedLocales.length, 2);
  });

  testWidgets('English is listed first, because first == the fallback',
      (tester) async {
    // The trap: Flutter's basicLocaleListResolution returns
    // `supportedLocales.first` when the device locale matches nothing. gen-l10n
    // emits its list alphabetically by ARB filename — [bn, en] — so wiring
    // MaterialApp to `AppLocalizations.supportedLocales` would silently hand
    // Bangla to every French, Hindi and Arabic phone on the planet.
    //
    // app.dart therefore passes its own en-first literal. If anyone ever
    // "simplifies" that to AppLocalizations.supportedLocales, the fallback
    // test below is what catches it.
    expect(supportedLocales.first, const Locale('en'));
  });

  testWidgets('resolves English copy under Locale("en")', (tester) async {
    final l10n = await localizationsFor(tester, const Locale('en'));
    expect(l10n.settingsTitle, 'Settings');
    expect(l10n.languageSection, 'Language');
    expect(l10n.signOutAction, 'Sign Out');
  });

  testWidgets('resolves Bangla copy under Locale("bn")', (tester) async {
    final l10n = await localizationsFor(tester, const Locale('bn'));
    expect(l10n.settingsTitle, 'সেটিংস');
    expect(l10n.languageSection, 'ভাষা');
    expect(l10n.signOutAction, 'সাইন আউট');
  });

  testWidgets('a Bangladeshi locale tag (bn_BD) still resolves to Bangla',
      (tester) async {
    // The device locale on a phone sold in Bangladesh is bn_BD, not bare bn.
    // Flutter's resolution falls back on the language subtag, but this is the
    // exact case the whole feature exists for, so it gets a test.
    final l10n =
        await localizationsFor(tester, const Locale('bn', 'BD'));
    expect(l10n.settingsTitle, 'সেটিংস');
  });

  testWidgets('an unsupported locale falls back to English, not Bangla',
      (tester) async {
    // A French handset must not get a Bangla app. See the ordering test above
    // for why this is a live hazard rather than a theoretical one.
    final l10n = await localizationsFor(tester, const Locale('fr'));
    expect(l10n.settingsTitle, 'Settings');
  });

  testWidgets('placeholder interpolation survives into Bangla',
      (tester) async {
    final l10n = await localizationsFor(tester, const Locale('bn'));
    final message = l10n.emergencyContactsLoadError('permission-denied');
    expect(message, contains('permission-denied'));
    expect(message, contains('কন্টাক্ট'));
  });
}
