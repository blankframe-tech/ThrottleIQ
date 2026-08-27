import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/group_ride_repository.dart';
import '../../domain/entities/group_ride_entity.dart';

final groupRideRepositoryProvider =
    Provider<GroupRideRepository>((ref) => GroupRideRepository());

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
