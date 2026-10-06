import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/photo_url_policy.dart';

void main() {
  group('isAllowedPhotoUrl (mirror of photoUrlAllowed in firestore.rules)', () {
    test('accepts empty, Cloudinary under our cloud, and Google avatars', () {
      expect(isAllowedPhotoUrl(null), isTrue);
      expect(isAllowedPhotoUrl(''), isTrue);
      expect(
          isAllowedPhotoUrl(
              'https://res.cloudinary.com/vjvcigkt/image/upload/v1/avatars/u/a.jpg'),
          isTrue);
      expect(isAllowedPhotoUrl('https://lh3.googleusercontent.com/a/x=s96-c'),
          isTrue);
      expect(isAllowedPhotoUrl('https://lh6.googleusercontent.com/a/x'), isTrue);
    });

    test('rejects other hosts, other Cloudinary clouds and plain http', () {
      expect(isAllowedPhotoUrl('https://attacker.example/p.gif'), isFalse);
      expect(
          isAllowedPhotoUrl(
              'https://res.cloudinary.com/someoneelse/image/upload/x.jpg'),
          isFalse);
      expect(isAllowedPhotoUrl('http://lh3.googleusercontent.com/a/x'), isFalse);
      expect(
          isAllowedPhotoUrl('https://lh3.googleusercontent.com.evil.example/x'),
          isFalse);
    });

    test('safePhotoUrl degrades a disallowed URL to empty', () {
      expect(safePhotoUrl('https://attacker.example/p.gif'), '');
      expect(safePhotoUrl(null), '');
      expect(safePhotoUrl('https://lh3.googleusercontent.com/a/x'),
          'https://lh3.googleusercontent.com/a/x');
    });
  });
}
