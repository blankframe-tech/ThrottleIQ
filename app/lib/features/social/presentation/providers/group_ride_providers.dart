import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../data/repositories/group_ride_repository.dart';
import '../../domain/entities/group_ride_entity.dart';
import '../../domain/utilities/group_ride_liveness.dart';

final groupRideRepositoryProvider =
    Provider<GroupRideRepository>((ref) => GroupRideRepository());

/// The signed-in rider's live group rides — the Social feed's "Riding Now"
/// strip, the ride cockpit's push-to-talk button and the Record screen's
/// "back to your group ride" banner. Empty (never an error state worth
/// showing) when signed out.
///
/// Filtered through [isGroupRideLive], not just the query's
/// `status == 'active'`: a ride whose creator's app was killed mid-ride is
/// never closed out on the server, and the query alone would keep listing it
/// forever. Re-evaluated every minute as well as on every snapshot, since a
/// ride goes stale by the clock with no document change to trigger a
/// re-emit.
///
/// Also self-heals: an abandoned ride the signed-in rider *created* is closed
/// out (status → completed) the first time it's seen, so it stops matching
/// the query for every member. Only the creator may write `status`
/// (firestore.rules update clause 1), so members just hide it locally.
///
/// `autoDispose`: it must not keep billing a live query for a screen nobody
/// has open.
final activeGroupRidesForUserProvider =
    StreamProvider.autoDispose<List<GroupRideEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  final repo = ref.watch(groupRideRepositoryProvider);

  final controller = StreamController<List<GroupRideEntity>>();
  final closedOut = <String>{};
  var latest = const <GroupRideEntity>[];

  void emit() {
    if (controller.isClosed) return;
    final now = DateTime.now();
    for (final ride in latest) {
      if (ride.creatorId == user.uid &&
          isGroupRideAbandoned(ride, now: now) &&
          closedOut.add(ride.id)) {
        unawaited(repo.endGroupRide(ride.id).catchError((Object _) {}));
      }
    }
    controller.add([
      for (final ride in latest)
        if (isGroupRideLive(ride, now: now)) ride,
    ]);
  }

  final sub = repo.watchActiveGroupRidesForUser(user.uid).listen(
    (rides) {
      latest = rides;
      emit();
    },
    onError: controller.addError,
  );
  final ticker = Timer.periodic(const Duration(minutes: 1), (_) => emit());
  ref.onDispose(() {
    ticker.cancel();
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// The one live group ride to surface from the ride screens — the most
/// recently started, when (unusually) the rider is on several. Null when
/// they're on none.
final currentLiveGroupRideProvider =
    Provider.autoDispose<GroupRideEntity?>((ref) {
  final rides =
      ref.watch(activeGroupRidesForUserProvider).valueOrNull ?? const [];
  if (rides.isEmpty) return null;
  return ([...rides]..sort((a, b) => b.startTime.compareTo(a.startTime)))
      .first;
});

/// How often the creator's device refreshes `lastActiveAt` while recording.
/// Far inside [kGroupRideInactiveCutoff], so a few missed beats (no signal)
/// never make a live ride look abandoned.
const Duration kGroupRideHeartbeatInterval = Duration(minutes: 5);

/// What a recording status change means for the rider's group rides.
enum GroupRideRecordingEffect { none, startHeartbeat, finish }

/// Pure transition table behind [groupRideLifecycleProvider]. "Riding" is
/// active or paused (a paused ride is still a ride in progress); leaving that
/// state for anything else — the rider tapped End, discarded, or a crash
/// alert stopped it — finishes the rider's group rides.
GroupRideRecordingEffect groupRideEffectFor({
  required bool wasRiding,
  required bool isRiding,
}) {
  if (!wasRiding && isRiding) return GroupRideRecordingEffect.startHeartbeat;
  if (wasRiding && !isRiding) return GroupRideRecordingEffect.finish;
  return GroupRideRecordingEffect.none;
}

bool _isRiding(RecordingStatus? s) =>
    s == RecordingStatus.active || s == RecordingStatus.paused;

/// Keeps group rides in step with the rider's own recording. Watched once
/// from the app root (`app.dart`), so it runs whichever screen is showing.
///
/// - While recording: heartbeats every group ride this rider created, so it
///   reads as live (see [isGroupRideLive]) even while they sit on the ride
///   cockpit instead of the group map.
/// - When the recording ends: closes the rider's group rides out via
///   `GroupRideRepository.finishGroupRidesForUser`. This is the source fix
///   for finished rides lingering in "Riding Now" — before it, only the
///   group map's Leave button ever set a ride to `completed`.
final groupRideLifecycleProvider = Provider<void>((ref) {
  Timer? heartbeat;
  void stopHeartbeat() {
    heartbeat?.cancel();
    heartbeat = null;
  }

  ref.onDispose(stopHeartbeat);

  ref.listen<RecordingStatus>(
    rideRecordingProvider.select((s) => s.status),
    (prev, next) {
      final uid = ref.read(currentUserProvider)?.uid;
      final repo = ref.read(groupRideRepositoryProvider);
      switch (groupRideEffectFor(
          wasRiding: _isRiding(prev), isRiding: _isRiding(next))) {
        case GroupRideRecordingEffect.startHeartbeat:
          if (uid == null || heartbeat != null) return;
          void beat() => unawaited(
              repo.heartbeatCreatedRides(uid).catchError((Object _) {}));
          beat();
          heartbeat = Timer.periodic(kGroupRideHeartbeatInterval, (_) => beat());
        case GroupRideRecordingEffect.finish:
          stopHeartbeat();
          if (uid == null) return;
          unawaited(repo
              .finishGroupRidesForUser(uid)
              .catchError((Object _) {}));
        case GroupRideRecordingEffect.none:
          break;
      }
    },
    fireImmediately: true,
  );
});

/// Live view of one group ride document — name, status, membership arrays.
///
/// `autoDispose` on purpose: this is only ever watched by the group-ride map
/// screen, and a Firestore document listener that outlived the screen would
/// keep billing reads for a ride nobody is looking at.
final groupRideProvider =
    StreamProvider.autoDispose.family<GroupRideEntity?, String>(
  (ref, groupRideId) =>
      ref.watch(groupRideRepositoryProvider).watchGroupRide(groupRideId),
);

/// Live view of one group ride's roster, from `groupRides/{id}/members/{uid}`.
///
/// Separate from [groupRideProvider] because it's a separate listener on a
/// separate collection; the map screen watches both and combines them with
/// `mergeGroupRideMembers` so rides created before the roster moved out of the
/// parent document still show their members.
final groupRideMembersProvider =
    StreamProvider.autoDispose.family<List<GroupRideMember>, String>(
  (ref, groupRideId) =>
      ref.watch(groupRideRepositoryProvider).watchGroupRideMembers(groupRideId),
);

/// Live view of a group ride's push-to-talk voice notes, oldest first.
///
/// `autoDispose` for the same reason as [groupRideProvider] — only the
/// group-ride map screen watches this, and it must not keep billing reads
/// for a ride nobody has open.
final voiceNotesProvider =
    StreamProvider.autoDispose.family<List<VoiceNoteEntity>, String>(
  (ref, groupRideId) =>
      ref.watch(groupRideRepositoryProvider).watchVoiceNotes(groupRideId),
);
