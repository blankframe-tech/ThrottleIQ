import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  group('currentBuildNumber', () {
    void mockBuild(String build) => PackageInfo.setMockInitialValues(
          appName: 'ThrottleIQ',
          packageName: 'com.bft.throttleiq',
          version: '1.0.0',
          buildNumber: build,
          buildSignature: '',
        );

    test('reads the platform build number', () async {
      mockBuild('26');
      expect(await currentBuildNumber(), 26);
    });

    test('an unreadable build number is 0, which never blocks', () async {
      mockBuild('');
      expect(await currentBuildNumber(), 0);
    });
  });

  group('watchUpdateRequired', () {
    Stream<bool> watch(Stream<Map<String, dynamic>?> config,
            {int build = 26}) =>
        watchUpdateRequired(currentBuild: build, config: config);

    test('follows config/app live: raising minBuild blocks a running app',
        () async {
      final config = StreamController<Map<String, dynamic>?>();
      final seen = <bool>[];
      final sub = watch(config.stream).listen(seen.add);
      config
        ..add({'minBuild': 20})
        ..add({'minBuild': 27})
        ..add({'minBuild': 26});
      await Future<void>.delayed(Duration.zero);
      expect(seen, [false, true, false]);
      await sub.cancel();
      await config.close();
    });

    test('a missing doc or field does not block', () async {
      expect(await watch(Stream.value(null)).single, isFalse);
      expect(await watch(Stream.value({'other': 1})).single, isFalse);
    });

    test('offline or denied does not block', () async {
      final seen = await watch(Stream.error(StateError('denied'))).toList();
      expect(seen, isEmpty);
    });

    test('an unknown build number never blocks or listens', () async {
      var listened = false;
      final config = Stream<Map<String, dynamic>?>.multi((c) {
        listened = true;
        c.add({'minBuild': 999});
      });
      expect(await watch(config, build: 0).single, isFalse);
      expect(listened, isFalse);
    });
  });

  test('the update link is Google Play on Android, the install page on iOS',
      () {
    expect(updateUrlFor(TargetPlatform.android),
        endsWith('id=com.bft.throttleiq'));
    expect(updateUrlFor(TargetPlatform.iOS), kInstallUrl);
  });

  testWidgets('the update screen offers Google Play (tests run as Android)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UpdateRequiredScreen(),
    ));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update on Google Play'), findsOneWidget);
    expect(kInstallUrl, startsWith('https://throttleiqfb.web.app/'));
  });
}
