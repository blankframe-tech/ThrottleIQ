import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/presentation/widgets/settings_oem_guide_tile.dart';
import 'package:throttleiq/features/ride/presentation/screens/oem_guide_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Settings → "Rides keep stopping?" reopens the battery guide (#37).
void main() {
  Future<void> pump(WidgetTester tester, OemBrand? brand) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SettingsOemGuideTile(brandLookup: () async => brand),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hidden on phones the guide does not cover', (tester) async {
    await pump(tester, null);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('on a covered brand it opens that brand\'s guide',
      (tester) async {
    await pump(tester, OemBrand.xiaomi);
    final l10n =
        AppLocalizations.of(tester.element(find.byType(SettingsOemGuideTile)));
    expect(find.text(l10n.oemGuideSettingsTitle), findsOneWidget);
    expect(find.text(l10n.oemGuideSettingsSubtitle('Xiaomi')), findsOneWidget);

    await tester.tap(find.text(l10n.oemGuideSettingsTitle));
    await tester.pumpAndSettle();
    final guide = tester.widget<OemGuideScreen>(find.byType(OemGuideScreen));
    expect(guide.brand, OemBrand.xiaomi);
  });
}
