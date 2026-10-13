import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';
import 'package:throttleiq/features/social/domain/utilities/follow_suggestions.dart';
import 'package:throttleiq/features/social/presentation/providers/follow_providers.dart';

UserProfileEntity p(String uid) => UserProfileEntity(uid: uid);

void main() {
  group('followBackCandidates (issues §90.A5)', () {
    test('drops me, people I follow and blocked riders; dedupes; caps', () {
      final out = followBackCandidates(
        myUid: 'me',
        followers: ['me', 'a', 'b', 'a', 'blocked', 'c', 'd'],
        following: {'b'},
        blocked: {'blocked'},
        cap: 2,
      );
      expect(out, ['a', 'c']);
    });
  });

  group('mergeSuggestions', () {
    test('follow-backs first, then recent riders, filtered and capped', () {
      final out = mergeSuggestions(
        myUid: 'me',
        followBack: [p('a')],
        recent: [
          p('me'),
          p('a'),
          p('x'),
          p('followed'),
          p('blocked'),
          p('y'),
          p('z')
        ],
        following: {'followed'},
        blocked: {'blocked'},
        cap: 3,
      );
      expect(out.map((e) => e.uid), ['a', 'x', 'y']);
    });

    test('default cap is 10', () {
      final out = mergeSuggestions(
        myUid: 'me',
        followBack: const [],
        recent: [for (var i = 0; i < 25; i++) p('u$i')],
        following: const {},
        blocked: const {},
      );
      expect(out, hasLength(kSuggestionCap));
    });
  });

  group('isFollowingProvider (issues §90.A6)', () {
    test('derives from the single follow-set stream', () async {
      final container = ProviderContainer(overrides: [
        followingUidsProvider
            .overrideWith((ref) => Stream.value(const {'alice'})),
      ]);
      addTearDown(container.dispose);

      final subA = container.listen(isFollowingProvider('alice'), (_, __) {});
      final subB = container.listen(isFollowingProvider('bob'), (_, __) {});
      await container.read(followingUidsProvider.future);

      expect(subA.read().valueOrNull, isTrue);
      expect(subB.read().valueOrNull, isFalse);
    });

    test('loading while the follow set is loading', () {
      final container = ProviderContainer(overrides: [
        followingUidsProvider
            .overrideWith((ref) => const Stream<Set<String>>.empty()),
      ]);
      addTearDown(container.dispose);
      expect(container.read(isFollowingProvider('alice')).isLoading, isTrue);
    });
  });
}
