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
  group('isAdmin', () {
    test('recognises the admin address', () {
      expect(isAdmin(kAdminEmail), isTrue);
    });

    // Firebase preserves whatever casing was typed at sign-up, so a raw ==
    // would let the admin lose their own privileges by capitalising a letter.
    test('is case-insensitive', () {
      expect(isAdmin('The.Abraar.Rar@Gmail.com'), isTrue);
      expect(isAdmin(kAdminEmail.toUpperCase()), isTrue);
    });

    test('rejects everyone else, and null', () {
      expect(isAdmin('someone.else@gmail.com'), isFalse);
      expect(isAdmin(null), isFalse);
      expect(isAdmin(''), isFalse);
    });

    // Guards against a lookalike address slipping through a prefix/suffix
    // comparison if this is ever rewritten.
    test('rejects addresses that merely contain the admin address', () {
      expect(isAdmin('x$kAdminEmail'), isFalse);
      expect(isAdmin('$kAdminEmail.attacker.com'), isFalse);
    });
  });

  group('canModerate', () {
    test('the admin can moderate any forum', () {
      expect(
        canModerate(forum: _forum(), uid: 'nobody', email: kAdminEmail),
        isTrue,
      );
    });

    test('the creator can moderate their own forum', () {
      final forum = _forum(createdBy: 'rider-1');
      expect(
        canModerate(forum: forum, uid: 'rider-1', email: 'rider1@x.com'),
        isTrue,
      );
    });

    test('a listed maintainer can moderate', () {
      final forum = _forum(createdBy: 'rider-1', maintainers: ['rider-2']);
      expect(
        canModerate(forum: forum, uid: 'rider-2', email: 'rider2@x.com'),
        isTrue,
      );
    });

    test('an unrelated rider cannot moderate', () {
      final forum = _forum(createdBy: 'rider-1', maintainers: ['rider-2']);
      expect(
        canModerate(forum: forum, uid: 'rider-9', email: 'rider9@x.com'),
        isFalse,
      );
    });

    test('a signed-out visitor cannot moderate', () {
      final forum = _forum(createdBy: 'rider-1');
      expect(canModerate(forum: forum, uid: null, email: null), isFalse);
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
      expect(canModerate(forum: auto, uid: 'rider-1', email: 'r@x.com'), isFalse);
      expect(canModerate(forum: auto, uid: 'rider-1', email: kAdminEmail), isTrue);
    });
  });

  group('canManageMaintainers', () {
    test('the admin can', () {
      expect(
        canManageMaintainers(forum: _forum(), uid: 'x', email: kAdminEmail),
        isTrue,
      );
    });

    test('the creator can', () {
      final forum = _forum(createdBy: 'rider-1');
      expect(
        canManageMaintainers(forum: forum, uid: 'rider-1', email: 'r1@x.com'),
        isTrue,
      );
    });

    // The deliberate narrowing: a maintainer moderates content but must not be
    // able to appoint peers or remove the creator who appointed them.
    test('a maintainer cannot — moderating is not appointing', () {
      final forum = _forum(createdBy: 'rider-1', maintainers: ['rider-2']);
      expect(
        canModerate(forum: forum, uid: 'rider-2', email: 'r2@x.com'),
        isTrue,
      );
      expect(
        canManageMaintainers(forum: forum, uid: 'rider-2', email: 'r2@x.com'),
        isFalse,
      );
    });

    test('a signed-out visitor cannot', () {
      expect(
        canManageMaintainers(forum: _forum(createdBy: 'r'), uid: null, email: null),
        isFalse,
      );
    });
  });
}
