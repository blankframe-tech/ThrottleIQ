import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/shared/widgets/app_shell.dart';

void main() {
  group('shellTabIndexForLocation', () {
    test('each tab path maps to its own index', () {
      for (var i = 0; i < shellTabs.length; i++) {
        expect(
          shellTabIndexForLocation(shellTabs[i]),
          i,
          reason: '${shellTabs[i]} should select index $i',
        );
      }
    });

    // The reported bug: maintenance is reached from the garage, but matched no
    // tab prefix and fell through to the Record fallback, so the wrong tab
    // appeared selected while the right screen was shown.
    test('/home/maintenance selects Profile, not Record', () {
      const profile = 4;
      expect(shellTabIndexForLocation('/home/maintenance'), profile);
      expect(shellTabIndexForLocation('/home/maintenance/add'), profile);
      expect(
        shellTabIndexForLocation('/home/maintenance?bikeId=abc123'),
        profile,
      );
      expect(
        shellTabIndexForLocation('/home/maintenance/add?bikeId=abc123'),
        profile,
      );
    });

    test('nested tab paths select their parent tab', () {
      expect(shellTabIndexForLocation('/home/profile/abc123'), 4);
      expect(shellTabIndexForLocation('/home/profile/abc123/edit'), 4);
      expect(shellTabIndexForLocation('/home/places/add'), 3);
      expect(shellTabIndexForLocation('/home/places/xyz'), 3);
    });

    test('query strings are ignored when matching', () {
      expect(shellTabIndexForLocation('/home/places?category=fuel'), 3);
    });

    test('an unknown location falls back to Record', () {
      expect(shellTabIndexForLocation('/home/nonsense'), 2);
      expect(shellTabIndexForLocation('/'), 2);
      expect(shellTabIndexForLocation(''), 2);
    });

    // A prefix match must respect path segment boundaries, or a future
    // '/home/recordings' route would silently steal the Record tab.
    test('does not match on a partial segment', () {
      expect(shellTabIndexForLocation('/home/recordings'), 2);
      expect(shellTabIndexForLocation('/home/socialite'), 2);
    });
  });
}
