import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/presentation/screens/add_edit_bike_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R9: the bike colour swatches were unlabeled GestureDetectors,
/// so a screen reader heard taps with no role, name or selected state.
void main() {
  testWidgets('colour swatches are labeled buttons with a selected state',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: AddEditBikeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final red = find.bySemanticsLabel('#E53935');
    expect(red, findsOneWidget);
    expect(
      tester.getSemantics(red),
      matchesSemantics(
        label: '#E53935',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(red);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(red), isSemantics(isSelected: true));
    handle.dispose();
  });
}
