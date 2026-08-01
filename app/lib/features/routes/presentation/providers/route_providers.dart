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

/// A single saved route belonging to the signed-in rider.
///
/// Scoped to the owner deliberately: a route doc lives under
/// `users/{uid}/routes/{id}`, so fetching someone else's needs their uid too.
/// Detail/navigation are only reachable from "My routes" today, so the
/// owner-scoped lookup is all that's wired. Opening a *discovered* route
/// would need the owner uid threaded through the route params as well.
final routeByIdProvider =
    FutureProvider.family<RouteEntity?, String>((ref, routeId) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;
  return _routeRepository.getRoute(userId: uid, routeId: routeId);
});
