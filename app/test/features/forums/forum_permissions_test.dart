import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/domain/entities/forum_entity.dart';
import 'package:throttleiq/features/forums/domain/forum_permissions.dart';

ForumEntity _forum({String? createdBy, List<String> maintainers = const []}) {
  return ForumEntity(
    id: 'c-two-stroke-club',
    type: ForumType.custom,
    brand: '',
    displayName: 'Two Stroke Club',
    createdBy: createdBy,
    maintainerIds: maintainers,
    createdAt: DateTime(2026, 8, 1),
  );
}

void main() {
  group('canModerate', () {
    test('the admin can moderate any forum', () {
      expect(
        canModerate(forum: _forum(), uid: 'nobody', isAdmin: true),
        isTrue,
      );
    });

    test('the creator can moderate their own forum', () {
      final forum = _forum(createdBy: 'rider-1');
      expect(
        canModerate(forum: forum, uid: 'rider-1', isAdmin: false),
        isTrue,
      );
    });

    test('a listed maintainer can moderate', () {
      final forum = _forum(createdBy: 'rider-1', maintainers: ['rider-2']);
      expect(
        canModerate(forum: forum, uid: 'rider-2', isAdmin: false),
        isTrue,
      );
    });

    test('an unrelated rider cannot moderate', () {
      final forum = _forum(createdBy: 'rider-1', maintainers: ['rider-2']);
      expect(
        canModerate(forum: forum, uid: 'rider-9', isAdmin: false),
        isFalse,
      );
    });

    test('a signed-out visitor cannot moderate', () {
      final forum = _forum(createdBy: 'rider-1');
      expect(canModerate(forum: forum, uid: null, isAdmin: false), isFalse);
    });

    // Auto-created bike/topic forums have no creator and no maintainers, so
    // only the admin should ever be able to moderate them.
    test('nobody but the admin can moderate an auto-created forum', () {
      final auto = ForumEntity(
        id: 'yamaha',
        type: ForumType.brand,
        brand: 'Yamaha',
        displayName: 'Yamaha',
        createdAt: DateTime(2026, 8, 1),
      );
      expect(canModerate(forum: auto, uid: 'rider-1', isAdmin: false), isFalse);
      expect(canModerate(forum: auto, uid: 'rider-1', isAdmin: true), isTrue);
    });
  });

  group('canManageMaintainers', () {
    test('the admin can', () {
      expect(
        canManageMaintainers(forum: _forum(), uid: 'x', isAdmin: true),
        isTrue,
      );
    });

    test('the creator can', () {
      final forum = _forum(createdBy: 'rider-1');
      expect(
        canManageMaintainers(forum: forum, uid: 'rider-1', isAdmin: false),
        isTrue,
      );
    });

    // The deliberate narrowing: a maintainer moderates content but must not be
    // able to appoint peers or remove the creator who appointed them.
    test('a maintainer cannot — moderating is not appointing', () {
      final forum = _forum(createdBy: 'rider-1', maintainers: ['rider-2']);
      expect(
        canModerate(forum: forum, uid: 'rider-2', isAdmin: false),
        isTrue,
      );
      expect(
        canManageMaintainers(forum: forum, uid: 'rider-2', isAdmin: false),
        isFalse,
      );
    });

    test('a signed-out visitor cannot', () {
      expect(
        canManageMaintainers(
            forum: _forum(createdBy: 'r'), uid: null, isAdmin: false),
        isFalse,
      );
    });
  });
}
