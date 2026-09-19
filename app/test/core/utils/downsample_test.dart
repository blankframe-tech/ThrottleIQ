import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/downsample.dart';

void main() {
  group('downsample', () {
    test('returns the list unchanged when already within budget', () {
      expect(downsample([1, 2, 3], 5), [1, 2, 3]);
    });

    test('thins a long list to the budget while keeping first and last', () {
      final input = List.generate(100, (i) => i);
      final out = downsample(input, 10);
      expect(out.length, 10);
      expect(out.first, 0);
      expect(out.last, 99);
    });

    test('a budget below 2 returns the list unchanged', () {
      expect(downsample([1, 2, 3], 1), [1, 2, 3]);
    });

    test('works generically over doubles', () {
      final input = List.generate(20, (i) => i * 1.5);
      final out = downsample(input, 4);
      expect(out.length, 4);
      expect(out.first, 0.0);
      expect(out.last, 19 * 1.5);
    });
  });
}
