import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/ride/presentation/screens/oem_guide_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  group('oemBrandFor', () {
    test('maps the original four makers and their sub-brands', () {
      expect(oemBrandFor('Xiaomi'), OemBrand.xiaomi);
      expect(oemBrandFor('Redmi'), OemBrand.xiaomi);
      expect(oemBrandFor('POCO'), OemBrand.xiaomi);
      expect(oemBrandFor('OPPO'), OemBrand.oppo);
      expect(oemBrandFor('realme'), OemBrand.realme);
      expect(oemBrandFor('vivo'), OemBrand.vivo);
      expect(oemBrandFor(' iQOO '), OemBrand.vivo);
    });

    test('maps Transsion brands and Samsung, bare or by company name', () {
      expect(oemBrandFor('TECNO'), OemBrand.tecno);
      expect(oemBrandFor('TECNO MOBILE LIMITED'), OemBrand.tecno);
      expect(oemBrandFor('Infinix'), OemBrand.infinix);
      expect(oemBrandFor('INFINIX MOBILITY LIMITED'), OemBrand.infinix);
      expect(oemBrandFor('itel'), OemBrand.itel);
      expect(oemBrandFor('ITEL MOBILE LIMITED'), OemBrand.itel);
      expect(oemBrandFor('samsung'), OemBrand.samsung);
    });

    test('any other maker gets no guide', () {
      expect(oemBrandFor('HUAWEI'), isNull);
      expect(oemBrandFor('itelligent'), isNull);
      expect(oemBrandFor('Google'), isNull);
      expect(oemBrandFor(null), isNull);
    });

    test('each brand links its dontkillmyapp page and an autostart screen', () {
      expect(OemBrand.xiaomi.guideUrl.toString(),
          'https://dontkillmyapp.com/xiaomi');
      for (final b in OemBrand.values) {
        expect(b.autostart, isNotEmpty, reason: b.name);
        expect(b.autostart.every((c) => c.contains('/')), isTrue);
      }
    });
  });

  group('maybeOfferOemGuide', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> offer(WidgetTester tester,
        {required bool hasFinishedRide, OemBrand? brand}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => maybeOfferOemGuide(context,
                hasFinishedRide: hasFinishedRide,
                brandLookup: () async => brand),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('not before the first finished ride', (tester) async {
      await offer(tester, hasFinishedRide: false, brand: OemBrand.xiaomi);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('not on other phones', (tester) async {
      await offer(tester, hasFinishedRide: true);
      expect(find.byType(AlertDialog), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOemGuideOfferedPref), isNull);
    });

    testWidgets('offered once; "Show me" opens the guide', (tester) async {
      await offer(tester, hasFinishedRide: true, brand: OemBrand.vivo);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('vivo'), findsWidgets);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(OemGuideScreen), findsOneWidget);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(OemGuideScreen)));
      expect(find.text(l10n.oemGuideOpenAutostart), findsOneWidget);
      expect(find.text(l10n.oemGuideStepLock), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await offer(tester, hasFinishedRide: true, brand: OemBrand.vivo);
      expect(find.byType(AlertDialog), findsNothing, reason: 'one time only');
    });
  });

  testWidgets('Samsung gets the Sleeping apps step, not Autostart',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OemGuideScreen(brand: OemBrand.samsung),
    ));
    final l10n =
        AppLocalizations.of(tester.element(find.byType(OemGuideScreen)));
    expect(find.text(l10n.oemGuideStepSleepingApps), findsOneWidget);
    expect(find.text(l10n.oemGuideOpenBatterySettings), findsOneWidget);
    expect(find.text(l10n.oemGuideOpenAutostart), findsNothing);
  });
}
