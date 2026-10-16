import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/sos_message.dart';

void main() {
  group('sosSmsUri', () {
    test('Android: comma-joined numbers, %20-encoded body', () {
      final uri = sosSmsUri(['+880 17-1234-5678', '01811 223344'], 'SOS help',
          iOS: false)!;
      expect(uri.toString(), 'sms:+8801712345678,01811223344?body=SOS%20help');
    });

    test('iOS: addresses form', () {
      final uri = sosSmsUri(['01712345678'], 'a&b', iOS: true)!;
      expect(uri.toString(), 'sms:/open?addresses=01712345678&body=a%26b');
    });

    test('drops undialable numbers; null when none are left', () {
      expect(sosSmsUri(['n/a', '01712345678'], 'x', iOS: false).toString(),
          'sms:01712345678?body=x');
      expect(sosSmsUri(['', '  ', 'none'], 'x', iOS: false), isNull);
      expect(sosSmsUri([], 'x', iOS: true), isNull);
    });

    test('newlines in the body survive encoding', () {
      final uri = sosSmsUri(['999'], 'line1\nline2', iOS: false)!;
      expect(uri.toString(), endsWith('body=line1%0Aline2'));
    });
  });

  test('sosMapLink uses plain decimal coordinates', () {
    expect(sosMapLink(23.7808875, 90.4161),
        'https://maps.google.com/?q=23.7808875,90.4161000');
  });
}
