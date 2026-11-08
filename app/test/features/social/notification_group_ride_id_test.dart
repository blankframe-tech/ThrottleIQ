import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/app_notification_entity.dart';

/// A notification's groupRideId becomes the `/group-ride/<id>` route when the
/// row is tapped, so only a document-id-shaped value may make it tappable: a
/// hand-written row must not steer the tap to another screen or add
/// `?start=1` (which starts a recording).
void main() {
  AppNotificationEntity row(NotificationType type, String? groupRideId) =>
      AppNotificationEntity(
        id: 'n1',
        type: type,
        fromUid: 'u1',
        fromName: 'Rider',
        createdAt: DateTime(2026, 11, 8),
        groupRideId: groupRideId,
      );

  test('a real group ride id is tappable', () {
    expect(
        row(NotificationType.groupRideInvite, 'aB3_x-9')
            .isActionableGroupRideInvite,
        isTrue);
    expect(
        row(NotificationType.groupRideJoined, 'aB3_x-9')
            .isViewableGroupRideJoined,
        isTrue);
  });

  test('a route-shaped, blank or missing id is not', () {
    for (final id in [
      '../settings',
      'x/../../profile/edit',
      'G1?start=1',
      'G1#top',
      'a b',
      '',
      'x' * 129,
      null,
    ]) {
      expect(
          row(NotificationType.groupRideInvite, id).isActionableGroupRideInvite,
          isFalse,
          reason: '$id');
      expect(
          row(NotificationType.groupRideJoined, id).isViewableGroupRideJoined,
          isFalse,
          reason: '$id');
    }
  });
}
