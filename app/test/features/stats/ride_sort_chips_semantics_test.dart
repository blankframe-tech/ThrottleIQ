import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/stats/domain/ride_sort.dart';
import 'package:throttleiq/features/stats/presentation/screens/all_rides_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §101.R9: the sort chips were bare GestureDetectors, so a screen
/// reader could not tell which sort was active.
void main() {
  testWidgets('the active sort chip is a selected button', (tester) async {
    final handle = tester.ensureSemantics();
    RideSort? picked;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: RideSortChips(
          sort: RideSort.recent,
          onChanged: (s) => picked = s,
        ),
      ),
    ));

    expect(
      tester.getSemantics(find.text('RECENT')),
      matchesSemantics(
        label: 'RECENT',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(tester.getSemantics(find.text('TOP SPEED')),
        isSemantics(isButton: true, isSelected: false));

    await tester.tap(find.text('TOP SPEED'));
    expect(picked, RideSort.topSpeed);
    handle.dispose();
  });
}
