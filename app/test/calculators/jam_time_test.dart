import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/jam_time.dart';

void main() {
  group('jamSeconds', () {
    test('is the ride clock minus moving time', () {
      expect(jamSeconds(durationSeconds: 1800, movingSeconds: 1200), 600);
    });

    test('a ride spent entirely moving has no jam time', () {
      expect(jamSeconds(durationSeconds: 600, movingSeconds: 600), 0);
    });

    test('a ride that never got moving is jam time end to end', () {
      expect(jamSeconds(durationSeconds: 300, movingSeconds: 0), 300);
    });

    test('clamps to zero rather than going negative', () {
      // Can happen on a resumed ride whose moving time was rebuilt from
      // disk-persisted fixes and slightly exceeds the restored elapsed
      // snapshot — see the doc comment on jamSeconds.
      expect(jamSeconds(durationSeconds: 100, movingSeconds: 105), 0);
    });
  });
}
