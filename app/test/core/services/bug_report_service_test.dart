import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/bug_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BugReportService', () {
    test('buildPayload constructs structured JSON with required fields', () async {
      final payload = await BugReportService.instance.buildPayload('Test description of an issue');

      expect(payload['app'], equals('ThrottleIQ'));
      expect(payload['description'], equals('Test description of an issue'));
      expect(payload.containsKey('timestamp'), isTrue);
      expect(payload.containsKey('version'), isTrue);
      expect(payload.containsKey('platform'), isTrue);
      expect(payload.containsKey('os'), isTrue);
      expect(payload.containsKey('uid'), isTrue);
    });

    test('buildPayload handles empty description cleanly', () async {
      final payload = await BugReportService.instance.buildPayload('');
      expect(payload['description'], equals(''));
      expect(payload['app'], equals('ThrottleIQ'));
    });
  });
}
