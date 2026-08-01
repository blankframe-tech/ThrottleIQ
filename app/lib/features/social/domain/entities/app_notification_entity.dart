enum NotificationType {
  follow,

  /// "X wants you to ride with them" — carries [AppNotificationEntity
  /// .groupRideId] so tapping the row can accept the invite and open the
  /// shared live map.
  groupRideInvite,
}

/// An in-app notification (currently just "so-and-so followed you" — the
/// `type` field exists so more kinds can be added later without a schema
/// rewrite). Real push (FCM) delivery isn't wired — that needs a Cloud
/// Function, and this project's Firebase plan doesn't support deploying
/// Cloud Functions yet (same Blaze-plan blocker as the rest of `functions/`,
/// see `todosanddone.md`). This is in-app only: it shows up next time the
/// rider opens the notifications screen, not as a phone push.
class AppNotificationEntity {
  final String id;
  final NotificationType type;
  final String fromUid;
  final String fromName;
  final String? fromPhotoUrl;
  final DateTime createdAt;
  final bool read;

  /// Deep-link payload for [NotificationType.groupRideInvite]; null for every
  /// other type. Kept as a plain nullable field rather than a generic `data`
  /// map so the one screen that reads it can't silently get a String where it
  /// expected an id.
  final String? groupRideId;

  const AppNotificationEntity({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    this.fromPhotoUrl,
    required this.createdAt,
    this.read = false,
    this.groupRideId,
  });

  /// True only when this row can actually be acted on — a group-ride invite
  /// written before the id field existed (or with a blank id) must not render
  /// a tappable "join the ride" affordance that would open nothing.
  bool get isActionableGroupRideInvite =>
      type == NotificationType.groupRideInvite &&
      (groupRideId != null && groupRideId!.isNotEmpty);
}
