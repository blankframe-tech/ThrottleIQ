import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/garage/data/bike_archive_service.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/garage/presentation/screens/bike_detail_screen.dart';
import 'package:throttleiq/features/maintenance/presentation/widgets/forecast_text.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

final _bike = BikeEntity(
  id: 'b1',
  userId: 'u1',
  brand: 'Yamaha',
  model: 'FZ',
  createdAt: DateTime(2026, 1, 1),
);

Widget _app(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('bn')],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('archive dialog keeps everything by default', (tester) async {
    ArchiveCleanup? result;
    await tester.pumpWidget(_app(
      const Locale('en'),
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<ArchiveCleanup>(
              context: context, builder: (_) => ArchiveBikeDialog(bike: _bike)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bike-archive')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isEmpty, isTrue);
  });

  testWidgets('ticked options are returned', (tester) async {
    ArchiveCleanup? result;
    await tester.pumpWidget(_app(
      const Locale('en'),
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<ArchiveCleanup>(
              context: context, builder: (_) => ArchiveBikeDialog(bike: _bike)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The options scroll inside the dialog; bring each into view first.
    for (final key in const [
      'archive-opt-logs',
      'archive-opt-fuel',
      'archive-opt-photos',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('bike-archive')));
    await tester.pumpAndSettle();

    expect(result!.serviceLogs, isTrue);
    expect(result!.fuelLogs, isTrue);
    expect(result!.photos, isTrue);
    expect(result!.sharedRides, isFalse);
    expect(result!.miles, isFalse);
  });

  testWidgets('Bangla dates read like English dates', (tester) async {
    late String short, long;
    await tester.pumpWidget(_app(
      const Locale('bn'),
      Builder(builder: (context) {
        short = shortDate(context, DateTime(2026, 10, 8));
        long = longDate(context, DateTime(2026, 10, 8));
        return const SizedBox();
      }),
    ));
    expect(short, '8 Oct');
    expect(long, '8 Oct 2026');
  });

  testWidgets('bottom-nav label is Garage in English and Bangla',
      (tester) async {
    late AppLocalizations en, bn;
    await tester.pumpWidget(_app(
      const Locale('en'),
      Builder(builder: (context) {
        en = AppLocalizations.of(context);
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(_app(
      const Locale('bn'),
      Builder(builder: (context) {
        bn = AppLocalizations.of(context);
        return const SizedBox();
      }),
    ));
    expect(en.navGarageLabel, 'Garage');
    expect(bn.navGarageLabel, 'গ্যারেজ');
  });
}
