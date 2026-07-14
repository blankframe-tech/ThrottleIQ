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
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/maintenance/presentation/screens/add_maintenance_log_screen.dart';
import '../../features/chatbot/presentation/screens/chatbot_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/social/presentation/screens/social_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = auth.valueOrNull != null;
      final isOnboarding = auth.valueOrNull?.displayName == null;
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;
      if (!isAuth && !loc.startsWith('/auth')) return '/auth/login';
      if (isAuth && isOnboarding && loc != '/auth/onboarding') {
        return '/auth/onboarding';
      }
      if (isAuth && loc.startsWith('/auth') && loc != '/auth/onboarding') {
        return '/home/record';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/auth/onboarding', builder: (_, __) => const OnboardingScreen()),
      // Full-screen ride routes (no shell)
      GoRoute(path: '/ride/active', builder: (_, __) => const ActiveRideScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/ride/summary/:rideId',
        builder: (_, state) => RideSummaryScreen(rideId: state.pathParameters['rideId']!),
      ),
      // Shell with bottom nav
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home/social', builder: (_, __) => const SocialScreen()),
          GoRoute(path: '/home/chatbot', builder: (_, __) => const ChatbotScreen()),
          GoRoute(path: '/home/record', builder: (_, __) => const RecordScreen()),
          GoRoute(
            path: '/home/maintenance',
            builder: (_, __) => const MaintenanceScreen(),
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
