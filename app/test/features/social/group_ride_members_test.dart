import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/group_ride_entity.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_members.dart';

void main() {
  final joinedAt = DateTime(2026, 3, 4, 10, 30);

  GroupRideMember member(
    String uid, {
    String? name,
    GroupRideMemberStatus status = GroupRideMemberStatus.joined,
  }) =>
      GroupRideMember(
        userId: uid,
        userName: name ?? uid,
        userPhotoUrl: '',
        joinedAt: joinedAt,
        status: status,
      );

  group('mergeGroupRideMembers', () {
    test('a current ride has only subcollection members', () {
      final merged = mergeGroupRideMembers(
        legacy: const [],
        fromSubcollection: [member('alpha'), member('zeta')],
      );

      expect(merged.map((m) => m.userId), ['alpha', 'zeta']);
    });

    test('a ride created before the move still shows its inline roster', () {
      final merged = mergeGroupRideMembers(
        legacy: [member('alpha'), member('zeta')],
        fromSubcollection: const [],
      );

      expect(merged.map((m) => m.userId), ['alpha', 'zeta']);
    });

    test(
      'the subcollection wins on collision — it is the only copy any current '
      'write touches, so the inline array is stale wherever they disagree',
      () {
        final merged = mergeGroupRideMembers(
          legacy: [
            member('alpha',
                name: 'Stale name', status: GroupRideMemberStatus.pending),
          ],
          fromSubcollection: [member('alpha', name: 'Alex')],
        );

        expect(merged, hasLength(1));
        expect(merged.single.userName, 'Alex');
        expect(merged.single.status, GroupRideMemberStatus.joined);
      },
    );

    test('a rider present in only one source is kept', () {
      final merged = mergeGroupRideMembers(
        legacy: [member('legacy-only')],
        fromSubcollection: [member('new-only')],
      );

      expect(merged.map((m) => m.userId), ['legacy-only', 'new-only']);
    });

    test(
      'the result is ordered by uid, which is what keeps each rider\'s marker '
      'colour from shifting when somebody else joins or leaves',
      () {
        final merged = mergeGroupRideMembers(
          legacy: [member('zeta')],
          fromSubcollection: [member('mid'), member('alpha')],
        );

        expect(merged.map((m) => m.userId), ['alpha', 'mid', 'zeta']);
      },
    );

    test('an entry with no uid is dropped rather than keyed to an empty id',
        () {
      final merged = mergeGroupRideMembers(
        legacy: [member(''), member('alpha')],
        fromSubcollection: [member('')],
      );

      expect(merged.map((m) => m.userId), ['alpha']);
    });

    test('two empty sources merge to an empty roster, not an error', () {
      expect(
        mergeGroupRideMembers(legacy: const [], fromSubcollection: const []),
        isEmpty,
      );
    });
  });
}
