import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/firestore_quota.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/profile/presentation/screens/sync_issues_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'alice';
}

/// Settings → Sync issues (§69.O4, §83.28) against a real in-memory SQLite
/// outbox; only the Firestore delivery is replaced (`deliverOverride`).
void main() {
  sqfliteFfiInit();
  late Database db;
  late OutboxDao dao;
  late bool deliverSucceeds;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    dao = OutboxDao();
    deliverSucceeds = false;
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  /// Real I/O doesn't advance on the fake test clock: lets it run until
  /// [until] shows (capped at ~2 s, so a miss fails the expect after it).
  Future<void> settle(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (until.evaluate().isNotEmpty) break;
    }
  }

  /// The list has loaded: either the empty state or a card.
  final loaded = find.byWidgetPredicate((w) =>
      w is Text &&
      (w.data == 'Everything is synced' || w.data == 'Ride share'));

  /// Queues an entry and drives it to the dead letter the way the outbox
  /// does: three permanent rejections.
  Future<void> seedDead(WidgetTester tester, String id, String kind,
      {required String owner}) async {
    await tester.runAsync(() async {
      final failing = OutboxService(
        dao: dao,
        quota: FirestoreQuota(),
        currentUid: () => owner,
        deliverOverride: (_) async => throw FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await dao.enqueue(id: id, kind: kind, payload: {'userId': owner});
      for (var i = 0; i < 3; i++) {
        await failing.drain();
        await db.update('outbox', {'next_attempt_at': null});
      }
      failing.dispose();
    });
  }

  Future<void> pump(WidgetTester tester) async {
    final service = OutboxService(
      dao: dao,
      quota: FirestoreQuota(),
      currentUid: () => 'alice',
      deliverOverride: (_) async {
        if (deliverSucceeds) return OutboxDeliveryResult.delivered;
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      },
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        outboxServiceProvider.overrideWithValue(service),
        currentUserProvider.overrideWithValue(_FakeUser()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SyncIssuesScreen(),
      ),
    ));
    await settle(tester, loaded);
  }

  testWidgets('nothing dead: says everything is synced', (tester) async {
    await pump(tester);
    expect(find.text('Everything is synced'), findsOneWidget);
  });

  testWidgets("lists only this rider's dead writes, by kind", (tester) async {
    await seedDead(tester, 'share:r1', OutboxKind.shareRide, owner: 'alice');
    await seedDead(tester, 'share:r2', OutboxKind.shareRide, owner: 'bob');
    await pump(tester);

    expect(find.text('Ride share'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsOneWidget);
    expect(find.text('Everything is synced'), findsNothing);
  });

  testWidgets('Retry that delivers: says Synced and the row drops off',
      (tester) async {
    await seedDead(tester, 'share:r1', OutboxKind.shareRide, owner: 'alice');
    await pump(tester);
    deliverSucceeds = true;

    await tester.tap(find.text('Retry'));
    await settle(tester, find.text('Synced'));

    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Everything is synced'), findsOneWidget);
    expect(await tester.runAsync(dao.all), isEmpty);
  });

  testWidgets('Retry that fails again: says so and keeps the write queued',
      (tester) async {
    await seedDead(tester, 'share:r1', OutboxKind.shareRide, owner: 'alice');
    await pump(tester);

    await tester.tap(find.text('Retry'));
    await settle(tester,
        find.text("Couldn't sync yet. We'll keep trying in the background."));

    expect(find.text("Couldn't sync yet. We'll keep trying in the background."),
        findsOneWidget);
    final rows = (await tester.runAsync(dao.all))!;
    expect(rows.single.isDead, isFalse, reason: 'revived, back in line');
  });

  testWidgets('Discard asks first; Cancel keeps the write', (tester) async {
    await seedDead(tester, 'share:r1', OutboxKind.shareRide, owner: 'alice');
    await pump(tester);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this update?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Ride share'), findsOneWidget);
    expect(await tester.runAsync(dao.all), hasLength(1));
  });

  testWidgets('Discard confirmed: the write is deleted for good',
      (tester) async {
    await seedDead(tester, 'share:r1', OutboxKind.shareRide, owner: 'alice');
    await pump(tester);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Discard')));
    await settle(tester, find.text('Everything is synced'));

    expect(find.text('Everything is synced'), findsOneWidget);
    expect(await tester.runAsync(dao.all), isEmpty);
  });
}
