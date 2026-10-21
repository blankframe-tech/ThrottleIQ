import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/app_check_gate.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/shared/widgets/sideload_blocked_screen.dart';

void main() {
  // What firebase_app_check throws on Android when the backend refuses the
  // Play Integrity verdict of a sideloaded build.
  final rejected = FirebaseException(
    plugin: 'firebase_app_check',
    message: 'Error returned from API. code: 403 body: App attestation failed.',
  );
  final offline = FirebaseException(
    plugin: 'firebase_app_check',
    message: 'java.net.UnknownHostException: Unable to resolve host '
        '"firebaseappcheck.googleapis.com"',
  );
  final serviceDisabled = FirebaseException(
    plugin: 'firebase_app_check',
    message: 'Error returned from API. code: 403 body: Firebase App Check API '
        'has not been used in project 1 before or it is disabled. '
        'SERVICE_DISABLED',
  );

  group('shouldBlockSideload', () {
    bool block({
      bool android = true,
      bool debug = false,
      String? installer = 'com.google.android.packageinstaller',
      Object? error,
    }) =>
        shouldBlockSideload(
          isAndroid: android,
          usesDebugProvider: debug,
          installerStore: installer,
          tokenError: error,
        );

    test('a sideloaded Android release build that App Check rejects blocks',
        () {
      expect(block(error: rejected), isTrue);
      expect(block(installer: null, error: rejected), isTrue);
    });

    test('a token, a network error or a disabled API never blocks', () {
      expect(block(error: null), isFalse);
      expect(block(error: offline), isFalse);
      expect(block(error: serviceDisabled), isFalse);
      expect(block(error: StateError('unknown')), isFalse);
    });

    test('iOS, debug-provider builds and Play installs never block', () {
      expect(block(android: false, error: rejected), isFalse);
      expect(block(debug: true, error: rejected), isFalse);
      expect(block(installer: 'com.android.vending', error: rejected), isFalse);
    });
  });

  group('checkSideloadBlocked', () {
    Future<bool> check(
      Future<String?> Function() getToken, {
      bool android = true,
      bool debug = false,
      String? installer = 'com.google.android.packageinstaller',
    }) =>
        checkSideloadBlocked(
          isAndroid: android,
          usesDebugProvider: debug,
          installerStore: () async => installer,
          getToken: getToken,
          timeout: const Duration(milliseconds: 50),
        );

    test('blocks on an attestation rejection', () async {
      expect(await check(() async => throw rejected), isTrue);
    });

    test('a token or an offline fetch does not block', () async {
      expect(await check(() async => 'token'), isFalse);
      expect(await check(() async => throw offline), isFalse);
    });

    test('a fetch slower than the timeout does not block', () async {
      expect(await check(() => Completer<String?>().future), isFalse);
    });

    test('Play installs, iOS and debug builds never fetch a token', () async {
      var fetched = false;
      Future<String?> fetch() async {
        fetched = true;
        throw rejected;
      }

      expect(await check(fetch, installer: 'com.android.vending'), isFalse);
      expect(await check(fetch, android: false), isFalse);
      expect(await check(fetch, debug: true), isFalse);
      expect(fetched, isFalse);
    });

    test('an unreadable installer does not block', () async {
      final blocked = await checkSideloadBlocked(
        isAndroid: true,
        usesDebugProvider: false,
        installerStore: () async => throw StateError('no package info'),
        getToken: () async => throw rejected,
      );
      expect(blocked, isFalse);
    });
  });

  testWidgets('the sideload screen offers Play and the WhatsApp request',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SideloadBlockedScreen(),
    ));
    expect(find.text('Install ThrottleIQ from Google Play'), findsOneWidget);
    expect(find.text('Open the Play Store'), findsOneWidget);
    expect(find.textContaining('01327045005'), findsOneWidget);
    expect(
        kTestingWhatsAppUrl, startsWith('https://wa.me/8801327045005?text='));
    expect(kPlayStoreUrl, endsWith('id=com.bft.throttleiq'));
  });
}
