import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/parse_localized_number.dart';

void main() {
  group('parseLocalizedNumber', () {
    test('Bangla digits', () {
      expect(parseLocalizedNumber('১২৩৪৫'), 12345);
      expect(parseLocalizedInt('১২৩৪৫'), 12345);
    });
    test('grouping commas', () {
      expect(parseLocalizedNumber('12,000'), 12000);
      expect(parseLocalizedNumber('1,20,000'), 120000);
      expect(parseLocalizedNumber('1,234,567.5'), 1234567.5);
      expect(parseLocalizedInt('12,000'), 12000);
    });
    test('decimal comma', () {
      expect(parseLocalizedNumber('12,5'), 12.5);
      expect(parseLocalizedNumber('12.5'), 12.5);
    });
    test('rejects junk and non-finite', () {
      for (final s in [
        'NaN', 'Infinity', '-Infinity', '', 'abc', '-5x', 'a5',
        '1,2,3', '1.2.3', '5.', '1e5'
      ]) {
        expect(parseLocalizedNumber(s), isNull, reason: s);
      }
    });
    test('min and max', () {
      expect(parseLocalizedNumber('-5'), -5);
      expect(parseLocalizedNumber('-5', min: 0), isNull);
      expect(parseLocalizedNumber('5', max: 4), isNull);
      expect(parseLocalizedInt('2000', min: 1900, max: 2030), 2000);
      expect(parseLocalizedInt('1800', min: 1900), isNull);
    });
    test('int rejects fractions', () {
      expect(parseLocalizedInt('12.5'), isNull);
      expect(parseLocalizedInt('12.0'), 12);
    });
  });
}
