import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/data/services/nominatim_service.dart';

void main() {
  final service = NominatimService();

  group('NominatimService.parseReverse', () {
    test('builds a nearest-first locality string from structured parts', () {
      final result = service.parseReverse({
        'address': {
          'road': 'Begum Rokeya Sarani',
          'suburb': 'Mirpur',
          'city': 'Dhaka',
          'country': 'Bangladesh',
        },
      });

      expect(result, 'Mirpur, Begum Rokeya Sarani, Dhaka');
    });

    test('caps at three parts so the prefill stays editable', () {
      final result = service.parseReverse({
        'address': {
          'neighbourhood': 'Block C',
          'suburb': 'Bashundhara',
          'road': 'Road 7',
          'city_district': 'Badda',
          'city': 'Dhaka',
          'county': 'Dhaka District',
        },
      });

      expect(result, 'Block C, Bashundhara, Road 7');
    });

    test('drops duplicate values rather than repeating them', () {
      final result = service.parseReverse({
        'address': {
          'village': 'Savar',
          'town': 'Savar',
          'city': 'Dhaka',
        },
      });

      expect(result, 'Savar, Dhaka');
    });

    test('ignores blank and non-string values', () {
      final result = service.parseReverse({
        'address': {
          'road': '   ',
          'suburb': 42,
          'city': 'Khulna',
        },
      });

      expect(result, 'Khulna');
    });

    test('falls back to the first three parts of display_name', () {
      final result = service.parseReverse({
        'address': {'country': 'Bangladesh'},
        'display_name': 'Omuk School, Mirpur 10, Dhaka, 1216, Bangladesh',
      });

      expect(result, 'Omuk School, Mirpur 10, Dhaka');
    });

    test('returns null when there is nothing usable', () {
      expect(service.parseReverse({}), isNull);
      expect(service.parseReverse({'address': {}}), isNull);
      expect(
        service.parseReverse({'address': 'not a map', 'display_name': '  '}),
        isNull,
      );
    });
  });
}
