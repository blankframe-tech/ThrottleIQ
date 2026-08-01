import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/group_ride_repository.dart';
import '../providers/group_ride_providers.dart';
import '../providers/notification_providers.dart';
import 'group_ride_friend_picker.dart';

/// Entry point for "Ride with friends", meant to sit on the record screen
/// directly under the bike picker.
///
/// Deliberately self-contained — it owns the whole flow (pick riders → create
/// the ride → invite → notify → open the shared map) behind one `const`
/// constructor, so the record screen only ever needs the single line that
/// places it and never has to grow any group-ride state of its own.
class RideWithFriendsButton extends ConsumerStatefulWidget {
  const RideWithFriendsButton({super.key});

  @override
  ConsumerState<RideWithFriendsButton> createState() =>
      _RideWithFriendsButtonState();
}

class _RideWithFriendsButtonState extends ConsumerState<RideWithFriendsButton> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picked = await GroupRideFriendPickerSheet.show(context);
    if (!mounted || picked == null || picked.isEmpty) return;

    setState(() => _busy = true);

    final inviterName = (user.displayName ?? '').trim().isEmpty
        ? 'A rider'
        : user.displayName!.trim();

    try {
      final repo = ref.read(groupRideRepositoryProvider);
      final groupRideId = await repo.createGroupRide(
        creatorId: user.uid,
        creatorName: inviterName,
        creatorPhotoUrl: user.photoURL ?? '',
        name: "$inviterName's group ride",
        startTime: DateTime.now(),
        // The ride is live the moment it's created — this isn't a scheduled
        // "planned" meet-up, the creator's recording starts immediately.
        status: 'active',
        invitees: [
          for (final rider in picked)
            GroupRideInvitee(
              userId: rider.uid,
              userName: rider.bestName,
              userPhotoUrl: rider.photoUrl ?? '',
            ),
        ],
        maxParticipants: picked.length + 1,
      );

      await repo.inviteUsers(
        groupRideId: groupRideId,
        userIds: picked.map((r) => r.uid).toList(),
      );

      // In-app notifications only — see NotificationRepository
      // .notifyGroupRideInvite; a real phone push needs a Cloud Function that
      // this project doesn't deploy yet. One failed write must not sink the
      // whole ride, so these are individually best-effort.
      final notifications = ref.read(notificationRepositoryProvider);
      for (final rider in picked) {
        try {
          await notifications.notifyGroupRideInvite(
            toUid: rider.uid,
            fromUid: user.uid,
            fromName: inviterName,
            fromPhotoUrl: user.photoURL,
            groupRideId: groupRideId,
          );
        } catch (_) {/* invitation doc still exists; they can be re-pinged */}
      }

      if (!mounted) return;
      // `go`, not `push`, and the recording is kicked off by the destination
      // screen rather than here. RecordScreen's build schedules a
      // post-frame `context.go('/ride/active')` the instant recording turns
      // active — starting the ride while RecordScreen is still mounted would
      // race that redirect and dump the rider on the solo ride screen instead
      // of the group map. Replacing the route first tears RecordScreen down,
      // so by the time recording starts there is nothing left to redirect.
      context.go('/group-ride/$groupRideId?start=1');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't start the group ride: $e")),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _start,
      icon: _busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          : const Icon(Icons.groups_outlined, size: 20),
      label: Text(_busy ? 'Setting up…' : 'Ride with friends'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
      ),
    );
  }
}
