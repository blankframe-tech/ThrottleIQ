import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/group_ride_repository.dart';
import '../providers/group_ride_providers.dart';
import '../providers/notification_providers.dart';
import 'group_ride_friend_picker.dart';
import 'join_group_ride_by_code_sheet.dart';

/// Explicit Solo/Group choice on the Record screen, sitting where the plain
/// "Ride with friends" button used to — an up-front choice is more
/// discoverable than a single button that only ever meant "group."
///
/// Deliberately an inline segmented control rather than a separate screen:
/// the Record screen's whole design (see its own doc comments) already
/// treats adding screens between the rider and the throttle as a cost to
/// justify, not a default. Solo is the default and does nothing on its own —
/// slide/hold-to-start already *is* the solo flow — so picking it here is
/// purely making an implicit choice explicit. Picking Group reveals the two
/// real group actions: inviting friends (existing flow) or joining one by
/// code (new — see `group_ride_join_code.dart`).
class RideModeSelector extends ConsumerStatefulWidget {
  const RideModeSelector({super.key});

  @override
  ConsumerState<RideModeSelector> createState() => _RideModeSelectorState();
}

enum _RideMode { solo, group }

class _RideModeSelectorState extends ConsumerState<RideModeSelector> {
  _RideMode _mode = _RideMode.solo;
  bool _busy = false;

  Future<void> _inviteFriends() async {
    if (_busy) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picked = await GroupRideFriendPickerSheet.show(context);
    if (!mounted || picked == null || picked.isEmpty) return;

    setState(() => _busy = true);

    final inviterName = (user.displayName ?? '').trim().isEmpty
        ? 'A rider'
        : user.displayName!.trim();

    final invitees = [
      for (final rider in picked)
        GroupRideInvitee(
          userId: rider.uid,
          userName: rider.bestName,
          userPhotoUrl: rider.photoUrl ?? '',
        ),
    ];

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
        invitees: invitees,
        maxParticipants: picked.length + 1,
      );

      await repo.inviteUsers(groupRideId: groupRideId, invitees: invitees);

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

  Future<void> _joinByCode() async {
    if (_busy) return;
    final groupRideId = await JoinGroupRideByCodeSheet.show(context);
    if (!mounted || groupRideId == null) return;
    // `push`, not `go` — unlike creating a ride, joining one never starts
    // this rider's own recording (same as accepting an invite from
    // Notifications), so there's no redirect race to sidestep.
    context.push('/group-ride/$groupRideId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeSegment(
                  label: l10n.rideModeSoloLabel,
                  icon: Icons.person_outline,
                  selected: _mode == _RideMode.solo,
                  onTap: () => setState(() => _mode = _RideMode.solo),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ModeSegment(
                  label: l10n.rideModeGroupLabel,
                  icon: Icons.groups_outlined,
                  selected: _mode == _RideMode.group,
                  onTap: () => setState(() => _mode = _RideMode.group),
                ),
              ),
            ],
          ),
        ),
        if (_mode == _RideMode.group) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _inviteFriends,
                  icon: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(l10n.rideModeInviteFriendsAction,
                      overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _joinByCode,
                  icon: const Icon(Icons.pin_outlined, size: 18),
                  label: Text(l10n.rideModeJoinByCodeAction,
                      overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.surface : AppColors.textPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.surface : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
