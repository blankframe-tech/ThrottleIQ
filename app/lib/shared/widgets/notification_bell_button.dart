import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme_context.dart';

/// A bell icon button that opens `/notifications`, with a red unread-count
/// badge.
///
/// Moved here from `RecordScreen` 2026-08-17 when Notifications (and
/// Settings) moved to the Profile tab's header — see `GarageScreen`.
class NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  const NotificationBellButton({super.key, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.palette.danger,
                borderRadius: BorderRadius.circular(context.shape.radiusFull),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
