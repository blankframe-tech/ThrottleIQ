import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/utilities/group_ride_selection.dart';

void main() {
  group('validateGroupSelection bounds', () {
    test('0 selected is rejected', () {
      expect(validateGroupSelection(0)?.problem, GroupSelectionProblem.tooFew);
    });

    test('1 selected is accepted — riding with a single friend is valid', () {
      expect(validateGroupSelection(1), isNull);
    });

    test('0 is the only non-negative count below the minimum', () {
      final result = validateGroupSelection(0);
      expect(result?.problem, GroupSelectionProblem.tooFew);
      // How many more are needed — the picker turns this into a sentence, and
      // picks a singular or plural one off kMinGroupRideFriends. This file
      // used to assert on that English wording, which is exactly why the
      // string could never be translated (§83.23).
      expect(result?.shortBy, kMinGroupRideFriends);
    });

    test('$kMinGroupRideFriends selected is the first valid count', () {
      expect(validateGroupSelection(kMinGroupRideFriends), isNull);
    });

    test('$kMaxGroupRideFriends selected is the last valid count', () {
      expect(validateGroupSelection(kMaxGroupRideFriends), isNull);
    });

    test('${kMaxGroupRideFriends + 1} selected is rejected', () {
      expect(validateGroupSelection(kMaxGroupRideFriends + 1)?.problem,
          GroupSelectionProblem.tooMany);
    });

    test('every count strictly inside the bounds is valid', () {
      for (var n = kMinGroupRideFriends; n <= kMaxGroupRideFriends; n++) {
        expect(validateGroupSelection(n), isNull, reason: 'count $n');
      }
    });

    test('negative counts behave like zero rather than throwing', () {
      expect(validateGroupSelection(-5)?.problem, GroupSelectionProblem.tooFew);
      expect(validateGroupSelection(-5)?.shortBy,
          validateGroupSelection(0)?.shortBy);
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
