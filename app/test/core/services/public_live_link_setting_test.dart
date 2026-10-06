import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/public_live_link_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the public /r/@handle link is OFF by default (issues §90.D7)', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await PublicLiveLinkSetting.isEnabled(), isFalse);
  });

  test('turning it on persists', () async {
    SharedPreferences.setMockInitialValues({});
    await PublicLiveLinkSetting.setEnabled(true);
    expect(await PublicLiveLinkSetting.isEnabled(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PublicLiveLinkSetting.prefsKey), isTrue);
  });

  test('turning it off again persists (no uid → no Firestore write)', () async {
    SharedPreferences.setMockInitialValues(
        {PublicLiveLinkSetting.prefsKey: true});
    await PublicLiveLinkSetting.setEnabled(false);
    expect(await PublicLiveLinkSetting.isEnabled(), isFalse);
  });
}
