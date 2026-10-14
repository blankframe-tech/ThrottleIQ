import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/app_update_gate.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'package:throttleiq/shared/widgets/update_required_screen.dart';

void main() {
  group('isUpdateRequired', () {
    test('an older build is blocked', () {
      expect(isUpdateRequired(currentBuild: 26, minBuild: 27), isTrue);
    });

    test('the same or a newer build is not', () {
      expect(isUpdateRequired(currentBuild: 27, minBuild: 27), isFalse);
      expect(isUpdateRequired(currentBuild: 28, minBuild: 27), isFalse);
    });

    test('a minBuild typed as a double still compares', () {
      expect(isUpdateRequired(currentBuild: 26, minBuild: 27.0), isTrue);
    });

    test('fails open on an unknown build or a bad minBuild', () {
      expect(isUpdateRequired(currentBuild: 0, minBuild: 27), isFalse);
      expect(isUpdateRequired(currentBuild: 26, minBuild: null), isFalse);
      expect(isUpdateRequired(currentBuild: 26, minBuild: '27'), isFalse);
    });
  });

  group('checkUpdateRequired', () {
    Future<bool> check(Future<Map<String, dynamic>?> Function() read,
            {int build = 26}) =>
        checkUpdateRequired(
          currentBuild: build,
          readConfig: read,
          timeout: const Duration(milliseconds: 50),
        );

    test('blocks when config/app.minBuild is above this build', () async {
      expect(await check(() async => {'minBuild': 27}), isTrue);
    });

    test('a missing doc or field does not block', () async {
      expect(await check(() async => null), isFalse);
      expect(await check(() async => {'other': 1}), isFalse);
    });

    test('offline or denied does not block', () async {
      expect(
        await check(() async => throw StateError('unavailable')),
        isFalse,
      );
    });

    test('a read slower than the timeout does not block', () async {
      final never = Completer<Map<String, dynamic>?>();
      expect(await check(() => never.future), isFalse);
    });

    test('a build without APP_BUILD never reads the doc', () async {
      var read = false;
      final blocked = await check(() async {
        read = true;
        return {'minBuild': 999};
      }, build: 0);
      expect(blocked, isFalse);
      expect(read, isFalse);
    });
  });

  testWidgets('the update screen offers the install link', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UpdateRequiredScreen(),
    ));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Get the latest version'), findsOneWidget);
    expect(kInstallUrl, startsWith('https://blankframe.tech/'));
  });
}
