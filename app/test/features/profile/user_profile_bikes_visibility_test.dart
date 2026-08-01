import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/data/models/user_profile_model.dart';
import 'package:throttleiq/features/profile/domain/bike_visibility.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';

void main() {
  group('UserProfileEntity.bikesVisibility', () {
    test('defaults to public when the entity is constructed without it', () {
      const profile = UserProfileEntity(uid: 'u1');
      expect(profile.bikesVisibility, kBikesVisibilityPublic);
    });

    test('copyWith updates it', () {
      const profile = UserProfileEntity(uid: 'u1');
      final updated = profile.copyWith(bikesVisibility: kBikesVisibilityPrivate);
      expect(updated.bikesVisibility, kBikesVisibilityPrivate);
    });

    test('copyWith preserves it when not overridden', () {
      const profile = UserProfileEntity(
        uid: 'u1',
        bikesVisibility: kBikesVisibilityFollowers,
      );
      final updated = profile.copyWith(nickname: 'Slick');
      expect(updated.bikesVisibility, kBikesVisibilityFollowers);
    });

    test('is part of equality — two profiles differing only in it are unequal', () {
      const a = UserProfileEntity(uid: 'u1', bikesVisibility: kBikesVisibilityPublic);
      const b = UserProfileEntity(uid: 'u1', bikesVisibility: kBikesVisibilityPrivate);
      expect(a, isNot(equals(b)));
      expect(a, equals(const UserProfileEntity(uid: 'u1')));
    });

    test('is independent of the profile-level visibility field', () {
      const profile = UserProfileEntity(
        uid: 'u1',
        visibility: 'public',
        bikesVisibility: kBikesVisibilityPrivate,
      );
      expect(profile.visibility, 'public');
      expect(profile.bikesVisibility, kBikesVisibilityPrivate);
    });
  });

  group('UserProfileModel.fromFirestore — bikesVisibility', () {
    test('decodes each stored tier verbatim', () {
      for (final level in kBikesVisibilityLevels) {
        final profile =
            UserProfileModel.fromFirestore({'bikesVisibility': level}, 'u1');
        expect(profile.bikesVisibility, level);
      }
    });

    test('a document with the field ABSENT decodes as public (legacy accounts)', () {
      final profile = UserProfileModel.fromFirestore(
        {'displayName': 'Old Timer', 'visibility': 'mutual'},
        'legacyUid',
      );
      expect(profile.bikesVisibility, kBikesVisibilityPublic);
      // ...and the pre-existing profile visibility is untouched by the new field.
      expect(profile.visibility, 'mutual');
    });

    test('an explicit null decodes as public too', () {
      final profile =
          UserProfileModel.fromFirestore({'bikesVisibility': null}, 'u1');
      expect(profile.bikesVisibility, kBikesVisibilityPublic);
    });

    test('round-trips through the field name Firestore actually stores', () {
      // setBikesVisibility writes exactly this key; decoding it must give the
      // same tier back, or the setting would silently reset on next read.
      const stored = {'bikesVisibility': kBikesVisibilityFollowers};
      final decoded = UserProfileModel.fromFirestore(stored, 'u1');
      expect(decoded.bikesVisibility, kBikesVisibilityFollowers);
      expect(
        canSeeBikes(
          viewerUid: 'someoneElse',
          ownerUid: 'u1',
          visibility: decoded.bikesVisibility,
          viewerFollowsOwner: false,
        ),
        isFalse,
      );
    });

    test('a legacy doc lets any signed-in rider through, as it did before', () {
      final decoded = UserProfileModel.fromFirestore(const {}, 'u1');
      expect(
        canSeeBikes(
          viewerUid: 'someoneElse',
          ownerUid: 'u1',
          visibility: decoded.bikesVisibility,
          viewerFollowsOwner: false,
        ),
        isTrue,
      );
    });
  });
}
