import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/group_ride_repository.dart';
import '../../domain/entities/group_ride_entity.dart';

final groupRideRepositoryProvider =
    Provider<GroupRideRepository>((ref) => GroupRideRepository());

/// Live view of one group ride's roster.
///
/// `autoDispose` on purpose: this is only ever watched by the group-ride map
/// screen, and a Firestore document listener that outlived the screen would
/// keep billing reads for a ride nobody is looking at.
final groupRideProvider =
    StreamProvider.autoDispose.family<GroupRideEntity?, String>(
  (ref, groupRideId) =>
      ref.watch(groupRideRepositoryProvider).watchGroupRide(groupRideId),
);
