import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/garage/presentation/screens/garage_screen.dart';
import '../../features/garage/presentation/screens/add_edit_bike_screen.dart';
import '../../features/garage/presentation/screens/bike_detail_screen.dart';
import '../../features/ride/presentation/screens/record_screen.dart';
import '../../features/ride/presentation/screens/active_ride_screen.dart';
import '../../features/ride/presentation/screens/ride_summary_screen.dart';
import '../../features/social/presentation/screens/ride_share_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/maintenance/presentation/screens/add_maintenance_log_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';
import '../../features/stats/presentation/screens/all_rides_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/social/presentation/screens/social_screen.dart';
import '../../features/social/presentation/screens/notifications_screen.dart';
import '../../features/social/presentation/screens/group_ride_map_screen.dart';
import '../../features/forums/presentation/screens/create_forum_screen.dart';
import '../../features/forums/presentation/screens/forum_thread_screen.dart';
import '../../features/forums/presentation/screens/forum_post_detail_screen.dart';
import '../../features/poi_directory/presentation/screens/places_list_screen.dart';
import '../../features/routes/presentation/screens/routes_list_screen.dart';
import '../../features/routes/presentation/screens/route_detail_screen.dart';
import '../../features/routes/presentation/screens/route_navigation_screen.dart';
import '../../features/routes/presentation/screens/save_route_screen.dart';
import '../../features/poi_directory/presentation/screens/add_place_screen.dart';
import '../../features/poi_directory/presentation/screens/place_detail_screen.dart';
import '../../features/poi_directory/presentation/screens/my_places_list_screen.dart';
import '../../features/social/presentation/screens/my_shared_rides_screen.dart';
import '../../shared/widgets/app_shell.dart';

/// Notifies GoRouter's `redirect` to re-run whenever [authStateProvider]
/// emits, without rebuilding [routerProvider] itself — rebuilding would
/// construct a brand-new GoRouter and reset the whole Navigator back to
/// initialLocation, wiping any in-progress screen state (e.g. onboarding's
/// bike-entry step).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

/// Pure redirect decision, extracted for unit testing (see app_router_test.dart).
/// Returns the path to redirect to, or null to stay put.
String? computeAuthRedirect({
  required bool isAuth,
  required bool isOnboarding,
  required String loc,
}) {
  if (loc == '/splash') return null;
  if (!isAuth && !loc.startsWith('/auth')) return '/auth/login';
  if (isAuth && isOnboarding && loc != '/auth/onboarding') {
    return '/auth/onboarding';
  }
  if (isAuth && loc.startsWith('/auth') && loc != '/auth/onboarding') {
    return '/home/record';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      // Read fresh on every call — redirect must never close over a stale
      // auth snapshot from provider-build time.
      final auth = ref.read(authStateProvider);
      return computeAuthRedirect(
        isAuth: auth.valueOrNull != null,
        isOnboarding: auth.valueOrNull?.displayName == null,
        loc: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/auth/onboarding', builder: (_, __) => const OnboardingScreen()),
      // Full-screen ride routes (no shell)
      GoRoute(path: '/ride/active', builder: (_, __) => const ActiveRideScreen()),
      // Group ride live map. Full-screen like /ride/active — it must NOT go
      // inside the ShellRoute. `?start=1` is set by the "Ride with friends"
      // flow; the destination screen starts the recording rather than the
      // button, so RecordScreen is torn down first and can't redirect the
      // rider onto the solo ride screen mid-navigation.
      GoRoute(
        path: '/group-ride/:groupRideId',
        builder: (_, state) => GroupRideMapScreen(
          groupRideId: state.pathParameters['groupRideId']!,
          autoStartRide: state.uri.queryParameters['start'] == '1',
        ),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      // The rider's OWN profile, read-only. Same screen as '/profile/:uid'
      // with the uid omitted — it resolves to the signed-in rider and adds an
      // "Edit" action. Both literals must precede '/profile/:uid' below.
      GoRoute(path: '/profile', builder: (_, __) => const UserProfileScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      // Must come after the literal '/profile/edit' above — go_router tries
      // routes in listed order, so the exact-match route wins for that one
      // path and every other uid falls through to this param route.
      GoRoute(
        path: '/profile/:uid',
        builder: (_, state) => UserProfileScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: '/ride/summary/:rideId',
        builder: (_, state) => RideSummaryScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(
        path: '/ride/share/:rideId',
        builder: (_, state) => RideShareScreen(rideId: state.pathParameters['rideId']!),
      ),
      // Forum routes (full-screen, no shell — same treatment as ride/summary).
      // '/forums/create' MUST stay above '/forums/:forumId': go_router tries
      // routes in listed order, so the param route would otherwise swallow
      // 'create' and try to open a forum whose slug is literally "create"
      // (same ordering hazard as '/profile/edit' vs '/profile/:uid' above).
      GoRoute(path: '/forums/create', builder: (_, __) => const CreateForumScreen()),
      GoRoute(
        path: '/forums/:forumId',
        builder: (_, state) => ForumThreadScreen(forumId: state.pathParameters['forumId']!),
        routes: [
          GoRoute(
            path: 'post/:postId',
            builder: (_, state) => ForumPostDetailScreen(
              forumId: state.pathParameters['forumId']!,
              postId: state.pathParameters['postId']!,
            ),
          ),
        ],
      ),
      // "My places" — reached from the garage header's user menu, not the
      // Places tab, so it gets the same full-screen no-shell treatment as
      // /profile/edit rather than living under /home/places.
      GoRoute(path: '/places/mine', builder: (_, __) => const MyPlacesListScreen()),
      GoRoute(path: '/rides/mine', builder: (_, __) => const MySharedRidesScreen()),
      // Opened from the Stats "All rides" button, on top of the current
      // screen — same full-screen no-shell treatment as /ride/summary.
      GoRoute(path: '/rides/all', builder: (_, __) => const AllRidesScreen()),
      // Saved routes. '/routes' and '/routes/save/:rideId' are both listed
      // before '/routes/:routeId' so the param route can't swallow them —
      // same ordering hazard as '/forums/create' and '/profile/edit'.
      GoRoute(path: '/routes', builder: (_, __) => const RoutesListScreen()),
      GoRoute(
        path: '/routes/save/:rideId',
        builder: (_, state) =>
            SaveRouteScreen(rideId: state.pathParameters['rideId']!),
      ),
      // `?owner=<uid>` names the rider a route belongs to, for routes opened
      // from Discover. A route doc lives at `users/{ownerUid}/routes/{id}`, so
      // without it a discovered route can only be looked up under the *viewer's*
      // uid and is never found. Omitted (every link that already existed) means
      // "mine", so /routes/:routeId keeps working unchanged.
      GoRoute(
        path: '/routes/:routeId',
        builder: (_, state) => RouteDetailScreen(
          routeId: state.pathParameters['routeId']!,
          ownerUid: state.uri.queryParameters['owner'],
        ),
        routes: [
          GoRoute(
            path: 'navigate',
            builder: (_, state) => RouteNavigationScreen(
              routeId: state.pathParameters['routeId']!,
              ownerUid: state.uri.queryParameters['owner'],
            ),
          ),
        ],
      ),
      // Shell with bottom nav
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home/social', builder: (_, __) => const SocialScreen()),
          GoRoute(path: '/home/stats', builder: (_, __) => const StatsScreen()),
          GoRoute(path: '/home/record', builder: (_, __) => const RecordScreen()),
          GoRoute(
            path: '/home/places',
            builder: (_, __) => const PlacesListScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddPlaceScreen()),
              GoRoute(
                path: ':placeId',
                builder: (_, state) =>
                    PlaceDetailScreen(placeId: state.pathParameters['placeId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/home/maintenance',
            builder: (_, state) => MaintenanceScreen(
              bikeId: state.uri.queryParameters['bikeId'],
            ),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, state) => AddMaintenanceLogScreen(
                  bikeId: state.uri.queryParameters['bikeId'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/home/garage',
            builder: (_, __) => const GarageScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddEditBikeScreen()),
              GoRoute(
                path: ':bikeId',
                builder: (_, state) =>
                    BikeDetailScreen(bikeId: state.pathParameters['bikeId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => AddEditBikeScreen(
                      bikeId: state.pathParameters['bikeId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
