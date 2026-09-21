import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/shared/widgets/app_card.dart';

/// issues §74: on Retro (the only palette with a hard, blur-less offset
/// shadow) `AppCard` rendered as a solid block of the border color, because
/// the shadow was painted over the fill. A hard shadow paints a full offset
/// copy of the card, so the fill must be in the same decoration, painted
/// after it.
void main() {
  Widget host(AppColorPalette palette, Widget child) => MaterialApp(
        theme: ThemeData(extensions: [palette, AppShapeProfile.boxy]),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('fill is in the decoration that carries the hard shadow',
      (tester) async {
    for (final palette in [AppColorPalette.retroLight, AppColorPalette.retroDark]) {
      await tester.pumpWidget(host(palette, const AppCard(child: Text('x'))));
      final deco = tester
          .widgetList<Container>(find.descendant(
              of: find.byType(AppCard), matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .single;
      expect(deco.boxShadow, isNotNull, reason: 'Retro keeps its hard shadow');
      expect(deco.color, palette.surface,
          reason: 'a hard shadow with no fill above it swallows the card');
    }
  });

  testWidgets('an explicit color overrides the surface fill', (tester) async {
    await tester.pumpWidget(host(AppColorPalette.retroLight,
        const AppCard(color: Color(0xFF123456), child: Text('x'))));
    final deco = tester
        .widget<Container>(find.descendant(
            of: find.byType(AppCard), matching: find.byType(Container)))
        .decoration! as BoxDecoration;
    expect(deco.color, const Color(0xFF123456));
  });

  testWidgets('non-Retro palettes have no shadow and still fill', (tester) async {
    await tester.pumpWidget(
        host(AppColorPalette.calmingLight, const AppCard(child: Text('x'))));
    final deco = tester
        .widget<Container>(find.descendant(
            of: find.byType(AppCard), matching: find.byType(Container)))
        .decoration! as BoxDecoration;
    expect(deco.boxShadow, isNull);
    expect(deco.color, AppColorPalette.calmingLight.surface);
  });

  testWidgets('taps still reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppColorPalette.retroLight,
        AppCard(onTap: () => taps++, child: const Text('tap me'))));
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });
}
