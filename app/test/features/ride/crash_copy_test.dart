import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/features/ride/presentation/screens/active_ride_screen.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// CrtiQue_Oct14 B11: crash delivery to contacts is a mock
/// (functions/src/crash-core.ts), so the crash UI must not promise it, and it
/// shows only when the detector flag is on.
void main() {
  test('the crash takeover follows the detector flag', () {
    expect(
      showCrashOverlay(detected: true),
      SensorConstants.crashAlertsEnabled,
    );
    expect(showCrashOverlay(detected: true, detectorOn: true), isTrue);
    expect(showCrashOverlay(detected: true, detectorOn: false), isFalse);
    expect(showCrashOverlay(detected: false, detectorOn: true), isFalse);
  });

  test('English crash copy never promises to contact anyone', () {
    final l = AppLocalizationsEn();
    for (final s in [l.okEmergencyContactsWill, l.notifCrashBody(60)]) {
      expect(s, contains('does not contact anyone'));
      expect(s.toLowerCase(), isNot(contains('will be notified')));
      expect(s.toLowerCase(), isNot(contains('contacting')));
    }
  });

  test('Bangla crash copy never promises to contact anyone', () {
    final l = AppLocalizationsBn();
    for (final s in [l.okEmergencyContactsWill, l.notifCrashBody(60)]) {
      expect(s, contains('যোগাযোগ করে না'));
      expect(s, isNot(contains('জানানো হবে')));
    }
  });
}
