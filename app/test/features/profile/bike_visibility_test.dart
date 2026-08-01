import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/domain/bike_visibility.dart';

void main() {
  group('canSeeBikes', () {
    const owner = 'ownerUid';
    const viewer = 'viewerUid';

    group('the owner', () {
      test('always sees their own garage, whatever the setting', () {
        for (final level in [
          kBikesVisibilityPublic,
          kBikesVisibilityFollowers,
          kBikesVisibilityPrivate,
          'something-we-never-shipped',
        ]) {
          expect(
            canSeeBikes(
              viewerUid: owner,
              ownerUid: owner,
              visibility: level,
              viewerFollowsOwner: false,
            ),
            isTrue,
            reason: 'owner should see own bikes with visibility "$level"',
          );
        }
      });
    });

    group('public', () {
      test('any signed-in rider can see them', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: kBikesVisibilityPublic,
            viewerFollowsOwner: false,
          ),
          isTrue,
        );
      });

      test('the follow edge is irrelevant', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: kBikesVisibilityPublic,
            viewerFollowsOwner: true,
          ),
          isTrue,
        );
      });
    });

    group('followers', () {
      test('a follower can see them', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: kBikesVisibilityFollowers,
            viewerFollowsOwner: true,
          ),
          isTrue,
        );
      });

      test('a non-follower cannot', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: kBikesVisibilityFollowers,
            viewerFollowsOwner: false,
          ),
          isFalse,
        );
      });

      test('the owner still sees their own, even though they follow nobody', () {
        expect(
          canSeeBikes(
            viewerUid: owner,
            ownerUid: owner,
            visibility: kBikesVisibilityFollowers,
            viewerFollowsOwner: false,
          ),
          isTrue,
        );
      });
    });

    group('private', () {
      test('nobody else can see them, follower or not', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: kBikesVisibilityPrivate,
            viewerFollowsOwner: false,
          ),
          isFalse,
        );
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: kBikesVisibilityPrivate,
            viewerFollowsOwner: true,
          ),
          isFalse,
        );
      });
    });

    group('unknown / absent values default to public', () {
      test('the empty string (field absent on a legacy doc) reads as public', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: '',
            viewerFollowsOwner: false,
          ),
          isTrue,
        );
      });

      test('an unrecognized value reads as public, not as a lockout', () {
        expect(
          canSeeBikes(
            viewerUid: viewer,
            ownerUid: owner,
            visibility: 'mutual', // the PROFILE vocabulary, not the bikes one
            viewerFollowsOwner: false,
          ),
          isTrue,
        );
      });
    });

    group('signed-out viewer (empty uid)', () {
      test('an empty viewer uid never counts as owning an empty owner uid', () {
        expect(
          canSeeBikes(
            viewerUid: '',
            ownerUid: '',
            visibility: kBikesVisibilityPrivate,
            viewerFollowsOwner: false,
          ),
          isFalse,
        );
      });

      test('falls through to the tier for a normal owner', () {
        expect(
          canSeeBikes(
            viewerUid: '',
            ownerUid: owner,
            visibility: kBikesVisibilityPublic,
            viewerFollowsOwner: false,
          ),
          isTrue,
        );
        expect(
          canSeeBikes(
            viewerUid: '',
            ownerUid: owner,
            visibility: kBikesVisibilityPrivate,
            viewerFollowsOwner: false,
          ),
          isFalse,
        );
      });
    });
  });

  group('bikesVisibilityLabel', () {
    test('labels each known tier', () {
      expect(bikesVisibilityLabel(kBikesVisibilityPublic), 'Everyone');
      expect(bikesVisibilityLabel(kBikesVisibilityFollowers), 'My followers');
      expect(bikesVisibilityLabel(kBikesVisibilityPrivate), 'Only me');
    });

    test('an unknown value labels as the default tier', () {
      expect(bikesVisibilityLabel('nonsense'), 'Everyone');
    });
  });
}
