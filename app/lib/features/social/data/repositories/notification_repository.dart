import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification_entity.dart';

/// In-app notifications at `users/{uid}/notifications/{id}`. See
/// [AppNotificationEntity]'s doc comment for why this is in-app only, not a
/// phone push.
class NotificationRepository {
  static final NotificationRepository _instance = NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notifs(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  /// Writes a "you have a new follower" notification into [toUid]'s
  /// subcollection. Called from the follower's device right after
  /// [FollowRepository.follow] — kept as a separate call rather than folded
  /// into FollowRepository so that repository doesn't need to know about
  /// notification shapes for future edge types that shouldn't notify.
  Future<void> notifyFollow({
    required String toUid,
    required String fromUid,
    required String fromName,
    String? fromPhotoUrl,
  }) async {
    if (toUid == fromUid) return;
    await _notifs(toUid).add({
      'type': NotificationType.follow.name,
      'fromUid': fromUid,
      'fromName': fromName,
      'fromPhotoUrl': fromPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Stream<List<AppNotificationEntity>> watchNotifications(String uid) {
    return _notifs(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  AppNotificationEntity _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AppNotificationEntity(
      id: doc.id,
      type: NotificationType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => NotificationType.follow,
      ),
      fromUid: data['fromUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'A rider',
      fromPhotoUrl: data['fromPhotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
    );
  }

  Future<void> markRead(String uid, String notificationId) {
    return _notifs(uid).doc(notificationId).update({'read': true});
  }

  /// Marks every currently-unread notification in [ids] read in one batch —
  /// used when the notifications screen opens, so the unread badge clears
  /// without a per-item round trip.
  Future<void> markAllRead(String uid, List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_notifs(uid).doc(id), {'read': true});
    }
    await batch.commit();
  }
}
