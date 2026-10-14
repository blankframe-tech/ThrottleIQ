import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/shared/widgets/app_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

void main() {
  Widget host(AppColorPalette palette, Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: [palette, AppShapeProfile.curvy]),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(body: Center(child: child)),
      );

  BoxDecoration decoOf(WidgetTester tester) => tester
      .widget<Container>(find.descendant(
          of: find.byType(AppCard), matching: find.byType(Container)))
      .decoration! as BoxDecoration;

  testWidgets('fills with the palette surface, no shadow', (tester) async {
    for (final palette in [
      AppColorPalette.calmingLight,
      AppColorPalette.carbonMonoDark,
    ]) {
      await tester.pumpWidget(host(palette, const AppCard(child: Text('x'))));
      expect(decoOf(tester).color, palette.surface);
      expect(decoOf(tester).boxShadow, isNull);
    }
  });

  testWidgets('an explicit color overrides the surface fill', (tester) async {
    await tester.pumpWidget(host(AppColorPalette.calmingLight,
        const AppCard(color: Color(0xFF123456), child: Text('x'))));
    expect(decoOf(tester).color, const Color(0xFF123456));
  });

  testWidgets('taps still reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppColorPalette.calmingLight,
        AppCard(onTap: () => taps++, child: const Text('tap me'))));
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });
}
