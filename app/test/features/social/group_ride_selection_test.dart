import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_selection.dart';

void main() {
  group('validateGroupSelection bounds', () {
    test('0 selected is rejected', () {
      expect(validateGroupSelection(0), isNotNull);
      expect(validateGroupSelection(0), contains('$kMinGroupRideFriends'));
    });

    test('1 selected is accepted — riding with a single friend is valid', () {
      expect(validateGroupSelection(1), isNull);
    });

    test('0 is the only non-negative count below the minimum', () {
      final message = validateGroupSelection(0);
      expect(message, isNotNull);
      expect(message, contains('1 more'));
      // Singular noun, since the bound is one.
      expect(message, contains('rider'));
      expect(message, isNot(contains('riders')));
    });

    test('$kMinGroupRideFriends selected is the first valid count', () {
      expect(validateGroupSelection(kMinGroupRideFriends), isNull);
    });

    test('$kMaxGroupRideFriends selected is the last valid count', () {
      expect(validateGroupSelection(kMaxGroupRideFriends), isNull);
    });

    test('${kMaxGroupRideFriends + 1} selected is rejected', () {
      final message = validateGroupSelection(kMaxGroupRideFriends + 1);
      expect(message, isNotNull);
      expect(message, contains('$kMaxGroupRideFriends'));
    });

    test('every count strictly inside the bounds is valid', () {
      for (var n = kMinGroupRideFriends; n <= kMaxGroupRideFriends; n++) {
        expect(validateGroupSelection(n), isNull, reason: 'count $n');
      }
    });

    test('negative counts behave like zero rather than throwing', () {
      expect(validateGroupSelection(-5), isNotNull);
      expect(validateGroupSelection(-5), contains('$kMinGroupRideFriends more'));
    });

    test('the bounds are the ones the owner asked for', () {
      expect(kMinGroupRideFriends, 1);
      expect(kMaxGroupRideFriends, 10);
    });
  });

  group('canAddAnotherFriend', () {
    test('allows adding right up to the cap', () {
      expect(canAddAnotherFriend(0), isTrue);
      expect(canAddAnotherFriend(kMaxGroupRideFriends - 1), isTrue);
    });

    test('refuses the one that would exceed the cap', () {
      expect(canAddAnotherFriend(kMaxGroupRideFriends), isFalse);
      expect(canAddAnotherFriend(kMaxGroupRideFriends + 3), isFalse);
    });
  });
}
