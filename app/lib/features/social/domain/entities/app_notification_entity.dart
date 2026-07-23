enum NotificationType { follow }

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

  const AppNotificationEntity({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    this.fromPhotoUrl,
    required this.createdAt,
    this.read = false,
  });
}
