import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/database/daos/impact_event_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/ride/presentation/widgets/impact_question_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The after-ride "Did you fall?" card: one question per unanswered
/// tier-1+ impact, answers stored through ImpactEventDao.
void main() {
  sqfliteFfiInit();
  late Database db;
  var syncs = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    syncs = 0;
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  Future<void> seed(WidgetTester tester, {int tier = 1}) =>
      tester.runAsync(() => ImpactEventDao().insert({
            'id': 'ev-1',
            'ride_id': 'ride-1',
            'user_id': 'u1',
            'at': '2026-10-14T15:28:58.900Z',
            'tier': tier,
            'reason': 'tipOver',
            'speed_before_ms': 0.0,
            'created_at': '2026-10-14T15:29:30Z',
          }));

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [impactSyncTriggerProvider.overrideWithValue(() => syncs++)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
              child: ImpactQuestionCard(rideId: 'ride-1')),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<Map<String, Object?>> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => ImpactEventDao().getForRide('ride-1')))!
          .single;

  testWidgets('nothing to ask: the card takes no space', (tester) async {
    await seed(tester, tier: 0);
    await pumpCard(tester);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('"just a bump" labels the impact and thanks the rider',
      (tester) async {
    await seed(tester);
    await pumpCard(tester);
    expect(find.textContaining('Possible fall at'), findsOneWidget);

    await tester.tap(find.byKey(const Key('impact_answer_bump')));
    await settle(tester);

    final row = await stored(tester);
    expect(row['label'], 'bump');
    expect(row['synced'], 0);
    expect(syncs, 1);
    expect(find.text('Thanks — that helps.'), findsOneWidget);
  });

  testWidgets('"Yes" asks the follow-ups; an unhurt slow tumble is a fall',
      (tester) async {
    await seed(tester);
    await pumpCard(tester);

    await tester.tap(find.byKey(const Key('impact_answer_crash')));
    await settle(tester);
    await tester.tap(find.text('No injury'));
    await tester.tap(find.text('Rail crossing'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('impact_follow_up_save')));
    await settle(tester);

    final row = await stored(tester);
    expect(row['label'], 'fall');
    expect(jsonDecode(row['label_detail']! as String),
        {'severity': 'none', 'surface': 'rail_crossing'});
  });
}

/// The DAO runs real I/O, which the fake test clock doesn't advance.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}
