import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/widgets/end_ride_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The end-ride sheet (claude_sol.md §3.1.1). What matters is that a ride
/// can't be ended by a tap, and that the share toggle's state reaches the
/// caller. Same ticker note as hold_to_start_button_test.dart: pump once
/// after pointer-down before any timed pump.
void main() {
  late EndRideChoice? result;
  late bool closed;

  Future<void> openSheet(WidgetTester tester) async {
    closed = false;
    result = null;
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showEndRideSheet(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> hold(WidgetTester tester, Duration d) async {
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('holdToEndButton'))));
    await tester.pump();
    await tester.pump(d);
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('controls meet the glove-size floor', (tester) async {
    await openSheet(tester);
    expect(tester.getSize(find.byKey(const Key('holdToEndButton'))).height,
        greaterThanOrEqualTo(72));
    expect(tester.getSize(find.byKey(const Key('endRideShareToggle'))).height,
        greaterThanOrEqualTo(56));
    expect(
        tester.getSize(find.widgetWithText(OutlinedButton, 'Keep riding')).height,
        greaterThanOrEqualTo(56));
  });

  testWidgets('a tap does not end the ride', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('holdToEndButton')));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Hold to end ride'), findsOneWidget);
  });

  testWidgets('a short hold unwinds without ending', (tester) async {
    await openSheet(tester);
    await hold(tester, const Duration(milliseconds: 600));
    expect(closed, isFalse);
  });

  testWidgets('a full hold ends the ride without sharing', (tester) async {
    await openSheet(tester);
    await hold(tester, const Duration(milliseconds: 1300));
    expect(closed, isTrue);
    expect(result?.share, isFalse);
  });

  testWidgets('share toggle is carried through', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('endRideShareToggle')));
    await tester.pump();
    await hold(tester, const Duration(milliseconds: 1300));
    expect(result?.share, isTrue);
  });

  testWidgets('Keep riding closes with no choice', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Keep riding'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
