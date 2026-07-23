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
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/social/presentation/screens/social_screen.dart';
import '../../features/social/presentation/screens/notifications_screen.dart';
import '../../features/forums/presentation/screens/forum_thread_screen.dart';
import '../../features/forums/presentation/screens/forum_post_detail_screen.dart';
import '../../features/poi_directory/presentation/screens/places_list_screen.dart';
import '../../features/poi_directory/presentation/screens/add_place_screen.dart';
import '../../features/poi_directory/presentation/screens/place_detail_screen.dart';
import '../../features/poi_directory/presentation/screens/my_places_list_screen.dart';
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
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
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
      // Forum routes (full-screen, no shell — same treatment as ride/summary)
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
