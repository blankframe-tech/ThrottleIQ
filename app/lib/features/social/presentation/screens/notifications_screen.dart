import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../providers/group_ride_providers.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedRead = false;

  // Marks everything unread-at-open-time read, once, the first time this
  // screen's data arrives — not on every rebuild (the list itself doesn't
  // change just because read-state changed, but re-running this on every
  // build would just be redundant no-op writes).
  void _markAllReadOnce(List<AppNotificationEntity> notifications) {
    if (_markedRead) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final unreadIds = notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    _markedRead = true;
    ref.read(notificationRepositoryProvider).markAllRead(uid, unreadIds);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: AppColors.danger))),
        data: (notifications) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markAllReadOnce(notifications));

          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text('No notifications yet',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NotificationTile(notification: notifications[i]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerStatefulWidget {
  final AppNotificationEntity notification;
  const _NotificationTile({required this.notification});

  @override
  ConsumerState<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends ConsumerState<_NotificationTile> {
  bool _accepting = false;

  AppNotificationEntity get notification => widget.notification;

  String _label() {
    switch (notification.type) {
      case NotificationType.follow:
        return '${notification.fromName} started following you';
      case NotificationType.groupRideInvite:
        return '${notification.fromName} invited you to ride together';
    }
  }

  String _relativeTime() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Tapping a group-ride invite *is* the accept — the owner's flow is
  /// "their friend clicks on the notification [and] they all see everyone
  /// else on the map", so there's no separate accept step to get wrong.
  Future<void> _acceptGroupRideInvite() async {
    if (_accepting) return;
    final user = ref.read(currentUserProvider);
    final groupRideId = notification.groupRideId;
    if (user == null || groupRideId == null || groupRideId.isEmpty) return;

    setState(() => _accepting = true);
    try {
      await ref.read(groupRideRepositoryProvider).acceptInvitation(
            groupRideId: groupRideId,
            userId: user.uid,
            userName: (user.displayName ?? '').trim().isEmpty
                ? 'Rider'
                : user.displayName!.trim(),
            userPhotoUrl: user.photoURL ?? '',
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't join the ride: $e")));
      return;
    }
    if (!mounted) return;
    setState(() => _accepting = false);
    context.push('/group-ride/$groupRideId');
  }

  void _onTap() {
    if (notification.isActionableGroupRideInvite) {
      _acceptGroupRideInvite();
      return;
    }
    context.push('/profile/${notification.fromUid}');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.read ? AppColors.surface : AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: _accepting ? null : _onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              UserAvatar(photoUrl: notification.fromPhotoUrl, name: notification.fromName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_label(),
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        notification.isActionableGroupRideInvite
                            ? '${_relativeTime()} · tap to join'
                            : _relativeTime(),
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              if (_accepting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              else if (notification.isActionableGroupRideInvite)
                Icon(Icons.groups_outlined, size: 20, color: AppColors.primary),
              if (!notification.read)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
