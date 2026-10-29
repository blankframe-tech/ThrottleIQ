import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/services/bug_report_service.dart';
import 'package:throttleiq/core/services/gps_drop_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'ThrottleIQ',
        packageName: 'tech.blankframe.throttleiq',
        version: '2.3.4',
        buildNumber: '56',
        buildSignature: '',
      ));

  group('BugReportService', () {
    test('buildPayload reports the real app version and build (#30)', () async {
      final payload = await BugReportService.instance.buildPayload('x');
      expect(payload['version'], '2.3.4');
      expect(payload['build'], '56');
    });

    test('buildPayload constructs structured JSON with required fields',
        () async {
      final payload = await BugReportService.instance
          .buildPayload('Test description of an issue');

      expect(payload['app'], equals('ThrottleIQ'));
      expect(payload['description'], equals('Test description of an issue'));
      expect(payload.containsKey('timestamp'), isTrue);
      expect(payload.containsKey('version'), isTrue);
      expect(payload.containsKey('platform'), isTrue);
      expect(payload.containsKey('os'), isTrue);
      expect(payload.containsKey('uid'), isTrue);
    });

    test('buildPayload carries the GPS accuracy drop log', () async {
      SharedPreferences.setMockInitialValues({});
      await GpsDropLog.record('r1', kept: 10, dropped: 2);
      final payload = await BugReportService.instance.buildPayload('x');
      final drops = payload['gpsAccuracyDrops'] as List;
      expect(drops.single['dropped'], 2);
    });

    test('buildPayload handles empty description cleanly', () async {
      final payload = await BugReportService.instance.buildPayload('');
      expect(payload['description'], equals(''));
      expect(payload['app'], equals('ThrottleIQ'));
    });
  });
}
