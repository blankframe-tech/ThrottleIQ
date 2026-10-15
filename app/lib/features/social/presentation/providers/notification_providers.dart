import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/app_notification_entity.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

/// The signed-in rider's notifications, newest first. Empty (not an error)
/// when signed out.
final notificationsProvider = StreamProvider<List<AppNotificationEntity>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchNotifications(uid);
});

/// Drives the bell icon's badge count.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.read).length;
});
