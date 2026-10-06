import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification_entity.dart';

/// In-app notifications at `users/{uid}/notifications/{id}`. See
/// [AppNotificationEntity]'s doc comment for why this is in-app only, not a
/// phone push.
/// The one follow notification [fromUid] can have in anyone's inbox.
String followNotificationId(String fromUid) => 'follow_$fromUid';

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
  ///
  /// Written at the deterministic id [followNotificationId] with `set`, not
  /// `add` (issues §90.A9): a follow → unfollow → follow loop or a double tap
  /// used to stack one new notification per toggle. With a fixed id the
  /// first follow creates the doc; a later one targets the same doc, which
  /// firestore.rules treats as an update (owner-only) and rejects — callers
  /// treat that as "already notified" (see `FollowController`).
  Future<void> notifyFollow({
    required String toUid,
    required String fromUid,
    required String fromName,
    String? fromPhotoUrl,
  }) async {
    if (toUid == fromUid) return;
    await _notifs(toUid).doc(followNotificationId(fromUid)).set({
      'type': NotificationType.follow.name,
      'fromUid': fromUid,
      'fromName': fromName,
      'fromPhotoUrl': fromPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// Writes a "come ride with me" invite into [toUid]'s subcollection.
  ///
  /// Modelled exactly on [notifyFollow] — same shape, same "written from the
  /// *other* rider's device" model, same `fromUid == request.auth.uid` rule
  /// gate — plus [groupRideId], which is what makes the row tappable: the
  /// notifications screen accepts the invitation and opens that ride's shared
  /// map straight from the tile.
  ///
  /// In-app only. There is no phone push here and this method does not
  /// attempt one: a real FCM delivery needs a Cloud Function to fan out to the
  /// invitee's device token, and this project's `functions/` are still a
  /// documented stub. The invitee sees this the next time they open the app.
  Future<void> notifyGroupRideInvite({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String groupRideId,
    String? fromPhotoUrl,
  }) async {
    if (toUid == fromUid) return;
    await _notifs(toUid).add({
      'type': NotificationType.groupRideInvite.name,
      'fromUid': fromUid,
      'fromName': fromName,
      'fromPhotoUrl': fromPhotoUrl,
      'groupRideId': groupRideId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// Writes a "so-and-so joined your ride" notification into [toUid]'s
  /// (the ride creator's) subcollection. Fired after a rider successfully
  /// joins — by shared code ([GroupRideRepository.joinByCode]) or by
  /// accepting an invite ([GroupRideRepository.acceptInvitation]) — from the
  /// *joining* rider's device, same model as [notifyGroupRideInvite].
  ///
  /// Until this existed, joining a ride wrote no notification at all — a
  /// creator only found out a rider had joined by having the ride's live map
  /// open at the time.
  Future<void> notifyGroupRideJoined({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String groupRideId,
    String? fromPhotoUrl,
  }) async {
    if (toUid == fromUid) return;
    await _notifs(toUid).add({
      'type': NotificationType.groupRideJoined.name,
      'fromUid': fromUid,
      'fromName': fromName,
      'fromPhotoUrl': fromPhotoUrl,
      'groupRideId': groupRideId,
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
      groupRideId: data['groupRideId'] as String?,
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
