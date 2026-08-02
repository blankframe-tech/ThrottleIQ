import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/routes/domain/route_permissions.dart';

/// The one decision behind opening a *discovered* route read-only: a route doc
/// lives at `users/{ownerUid}/routes/{routeId}` and firestore.rules allow a
/// public route to be read by any signed-in rider but written only by its
/// owner. The detail screen hides the visibility toggle and Delete for anyone
/// this returns false for, so getting it wrong means offering a control the
/// rules will refuse.
void main() {
  group('canEditRoute', () {
    test('the owner can edit their own route', () {
      expect(canEditRoute(viewerUid: 'rider-1', ownerUid: 'rider-1'), isTrue);
    });

    test('another signed-in rider cannot edit a route they discovered', () {
      expect(canEditRoute(viewerUid: 'rider-2', ownerUid: 'rider-1'), isFalse);
    });

    test('a signed-out viewer cannot edit anything', () {
      expect(canEditRoute(viewerUid: null, ownerUid: 'rider-1'), isFalse);
    });

    test('an unknown owner is never editable, whoever is viewing', () {
      expect(canEditRoute(viewerUid: 'rider-1', ownerUid: null), isFalse);
      expect(canEditRoute(viewerUid: null, ownerUid: null), isFalse);
    });

    test(
      'empty strings are not a match — two blanks must not read as "the same '
      'rider" and hand a delete button to a signed-out viewer',
      () {
        expect(canEditRoute(viewerUid: '', ownerUid: ''), isFalse);
        expect(canEditRoute(viewerUid: '', ownerUid: 'rider-1'), isFalse);
        expect(canEditRoute(viewerUid: 'rider-1', ownerUid: ''), isFalse);
      },
    );
  });
}
