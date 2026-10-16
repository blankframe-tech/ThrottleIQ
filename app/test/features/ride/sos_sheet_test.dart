import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/widgets/sos_sheet.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

Widget _harness(List<String>? phones) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SosSheet(
          phones: phones,
          liveUrl: () async => null,
          mapUrl: null,
        ),
      ),
    );

void main() {
  testWidgets('no contacts: hint instead of texting, 999 still offered',
      (tester) async {
    await tester.pumpWidget(_harness(const []));
    expect(find.byKey(const Key('sosNoContacts')), findsOneWidget);
    expect(find.byKey(const Key('sosTextContacts')), findsNothing);
    expect(find.text('Call 999'), findsOneWidget);
  });

  testWidgets('only undialable numbers count as no contacts', (tester) async {
    await tester.pumpWidget(_harness(const ['n/a']));
    expect(find.byKey(const Key('sosNoContacts')), findsOneWidget);
  });

  testWidgets('with contacts: text action and 999', (tester) async {
    await tester.pumpWidget(_harness(const ['01712345678']));
    expect(find.text('Text my emergency contacts'), findsOneWidget);
    expect(find.byKey(const Key('sosCall999')), findsOneWidget);
    expect(find.byKey(const Key('sosNoContacts')), findsNothing);
  });

  testWidgets('loading contacts: spinner, 999 still offered', (tester) async {
    await tester.pumpWidget(_harness(null));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('sosCall999')), findsOneWidget);
  });
}
