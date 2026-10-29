import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/public_live_link_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the /r/@handle link is OFF by default (issues §90.D7)', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await PublicLiveLinkSetting.isEnabled(), isFalse);
  });

  test('the old password-less "on" flag does not turn the link on', () async {
    SharedPreferences.setMockInitialValues(
        {PublicLiveLinkSetting.legacyPrefsKey: true});
    expect(await PublicLiveLinkSetting.isEnabled(), isFalse);
  });

  test('linkKey matches the viewer page (live-viewer.html linkKey)', () {
    // sha256("throttleiq-r:u1:hunter22"); the page must hash the same string.
    expect(PublicLiveLinkSetting.linkKey('u1', 'hunter22'),
        '7d4dbde7ff972b126dba87e79932c15e0a816c780197f45d7b65fd1feeca53ed');
  });

  test('enabling stores only the key, never the password', () async {
    SharedPreferences.setMockInitialValues({});
    // Exactly the 12-character minimum is accepted.
    await PublicLiveLinkSetting.enable(uid: 'u1', password: 'hunter22hunt');
    expect(await PublicLiveLinkSetting.currentKey(),
        PublicLiveLinkSetting.linkKey('u1', 'hunter22hunt'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().map(prefs.get).any((v) => '$v'.contains('hunter22')),
        isFalse);
  });

  test('a password under 12 characters is refused', () async {
    SharedPreferences.setMockInitialValues({});
    await expectLater(
        PublicLiveLinkSetting.enable(uid: 'u1', password: 'eleven-char'),
        throwsArgumentError);
    expect(await PublicLiveLinkSetting.isEnabled(), isFalse);
  });

  test('the en and bn hints state the same minimum the code enforces', () {
    const min = '${PublicLiveLinkSetting.minPasswordLength}';
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_bn.arb']) {
      final strings = jsonDecode(File(arb).readAsStringSync()) as Map;
      expect(strings['publicLiveLinkPasswordBody'], contains(min), reason: arb);
      expect(strings['publicLiveLinkPasswordTooShort'], contains(min),
          reason: arb);
    }
  });

  test('disabling with no link set needs no Firestore write', () async {
    SharedPreferences.setMockInitialValues(
        {PublicLiveLinkSetting.legacyPrefsKey: true});
    await PublicLiveLinkSetting.disable();
    expect(await PublicLiveLinkSetting.isEnabled(), isFalse);
  });
}
