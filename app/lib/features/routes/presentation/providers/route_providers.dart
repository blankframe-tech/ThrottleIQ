import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/data/repositories/route_repository.dart';
import '../../../social/domain/entities/route_entity.dart';

final _routeRepository = RouteRepository();

/// Routes the signed-in rider has saved. Empty (not an error) when signed out.
final myRoutesProvider = FutureProvider<List<RouteEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const [];
  return _routeRepository.getUserRoutes(uid);
});

/// Public routes from every rider, for the Discover tab.
final publicRoutesProvider = FutureProvider<List<RouteEntity>>((ref) {
  return _routeRepository.getPublicRoutes();
});

/// Identifies one route document. A route lives at
/// `users/{ownerUid}/routes/{routeId}`, so the id alone is not enough to find
/// it — a *discovered* route belongs to another rider entirely.
///
/// [ownerUid] is null for "mine": the signed-in rider's uid is substituted, so
/// every existing `/routes/:routeId` link (which carries no owner) keeps
/// resolving exactly as it did.
typedef RouteLookup = ({String routeId, String? ownerUid});

/// A single saved route — the signed-in rider's own, or a public one from
/// another rider when [RouteLookup.ownerUid] names them.
///
/// A record is used as the family key on purpose: records compare structurally,
/// so two lookups for the same route/owner pair share one provider instance
/// instead of re-fetching.
final routeByIdProvider =
    FutureProvider.family<RouteEntity?, RouteLookup>((ref, lookup) async {
  final viewerUid = ref.watch(currentUserProvider)?.uid;
  final owner = (lookup.ownerUid != null && lookup.ownerUid!.isNotEmpty)
      ? lookup.ownerUid!
      : viewerUid;
  if (owner == null) return null;
  return _routeRepository.getRoute(userId: owner, routeId: lookup.routeId);
});
