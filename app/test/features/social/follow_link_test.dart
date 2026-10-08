import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/utilities/follow_link.dart';
import 'package:throttleiq/features/social/domain/utilities/follow_link_outcome.dart';

void main() {
  const uid = 'aB3dE5gH7jK9mN1pQ3sT5vX7zZ90';

  group('buildFollowLink', () {
    test('is the canonical blankframe.tech/ThrottleIQ/u/<uid> https link', () {
      expect(buildFollowLink(uid).toString(),
          'https://blankframe.tech/ThrottleIQ/u/$uid');
    });

    test('custom-scheme form is throttleiq://u/<uid>', () {
      expect(buildFollowSchemeLink(uid).toString(), 'throttleiq://u/$uid');
    });

    test('rejects a malformed uid instead of building a broken link', () {
      expect(() => buildFollowLink(''), throwsArgumentError);
      expect(() => buildFollowLink('a/b'), throwsArgumentError);
      expect(() => buildFollowLink('a b'), throwsArgumentError);
      expect(() => buildFollowLink('x' * 129), throwsArgumentError);
    });

    test('round-trips through the parser', () {
      expect(parseFollowLink(buildFollowLink(uid).toString()), uid);
      expect(parseFollowLink(buildFollowSchemeLink(uid).toString()), uid);
      expect(parseFollowUri(buildFollowLink(uid)), uid);
    });
  });

  group('parseFollowLink accepts', () {
    for (final link in [
      'https://blankframe.tech/ThrottleIQ/u/$uid',
      'https://blankframe.tech/ThrottleIQ/u/$uid/',
      'https://blankframe.tech/throttleiq/U/$uid',
      'http://blankframe.tech/ThrottleIQ/u/$uid',
      'https://www.blankframe.tech/ThrottleIQ/u/$uid',
      'https://BLANKFRAME.tech/ThrottleIQ/u/$uid',
      'https://blankframe.tech/ThrottleIQ/u/$uid?utm=qr#x',
      '  https://blankframe.tech/ThrottleIQ/u/$uid  ',
      'https://throttleiqfb.web.app/u/$uid',
      'https://throttleiqfb.web.app/ThrottleIQ/u/$uid',
      'https://throttleiqfb.firebaseapp.com/u/$uid',
      'throttleiq://u/$uid',
      'throttleiq://u/$uid/',
    ]) {
      test(link.trim(), () => expect(parseFollowLink(link), uid));
    }

    test('keeps the uid case-sensitive', () {
      expect(parseFollowLink('https://blankframe.tech/ThrottleIQ/u/AbC'), 'AbC');
    });

    test('uids with - and _ (emulator / custom auth)', () {
      expect(parseFollowLink('throttleiq://u/user_1-x'), 'user_1-x');
    });
  });

  group('parseFollowLink rejects', () {
    for (final link in <String?>[
      null,
      '',
      '   ',
      uid, // a bare uid is not a link
      'hello world',
      'https://evil.example/ThrottleIQ/u/$uid',
      'https://blankframe.tech.evil.example/ThrottleIQ/u/$uid',
      'https://blankframe.tech/ThrottleIQ/install',
      'https://blankframe.tech/ThrottleIQ/u/',
      'https://blankframe.tech/ThrottleIQ/u/$uid/extra',
      'https://blankframe.tech/u/$uid/extra',
      'https://blankframe.tech/Other/u/$uid',
      'https://blankframe.tech/ThrottleIQ/u/a%2Fb',
      'https://blankframe.tech/ThrottleIQ/u/${'x' * 129}',
      'ftp://blankframe.tech/ThrottleIQ/u/$uid',
      'throttleiq://startride',
      'throttleiq://u/',
      'throttleiq://x/$uid',
      'otherapp://u/$uid',
      'WIFI:S:home;T:WPA;P:secret;;',
    ]) {
      test(link ?? 'null', () => expect(parseFollowLink(link), isNull));
    }
  });

  group('precheckFollowLink', () {
    test('unparsed link is invalid, whatever else holds', () {
      expect(
          precheckFollowLink(targetUid: null, myUid: 'me', following: {}),
          FollowLinkOutcome.invalid);
      expect(precheckFollowLink(targetUid: null, myUid: null, following: {}),
          FollowLinkOutcome.invalid);
    });

    test('signed out stashes the follow for after sign-in', () {
      expect(precheckFollowLink(targetUid: uid, myUid: null, following: {}),
          FollowLinkOutcome.pendingSignIn);
    });

    test('own code', () {
      expect(precheckFollowLink(targetUid: 'me', myUid: 'me', following: {}),
          FollowLinkOutcome.self);
    });

    test('already following', () {
      expect(
          precheckFollowLink(
              targetUid: uid, myUid: 'me', following: {uid, 'other'}),
          FollowLinkOutcome.alreadyFollowing);
    });

    test('otherwise go ahead (null)', () {
      expect(
          precheckFollowLink(targetUid: uid, myUid: 'me', following: {'other'}),
          isNull);
    });
  });
}
