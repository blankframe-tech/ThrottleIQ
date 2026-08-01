import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/cloud/sync_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_style_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/ride/presentation/providers/ride_recording_provider.dart';

class ThrottleIQApp extends ConsumerWidget {
  const ThrottleIQApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      // Cloud sync lifecycle: start on login, stop on logout. SyncManager itself
      // no-ops when signed out, so starting is safe; stopping avoids idle timers.
      ref.listen(authStateProvider, (prev, next) {
        final sync = ref.read(syncManagerProvider);
        if (next.valueOrNull != null) {
          sync.startAutoSync();
          // Finish off any ride that was still "active" when the app last
          // died mid-recording (killed process, no chance to call
          // stopRide()) — see RideRecordingNotifier.recoverCrashRide's doc
          // comment. Only meaningful once signed in, since it touches the
          // per-user local ride DB.
          ref.read(rideRecordingProvider.notifier).recoverCrashRide();
        } else {
          sync.stopAutoSync();
        }
      });

      final router = ref.watch(routerProvider);
      final themeStyle = ref.watch(themeStyleProvider);
      // AppColors is a mutable static facade (see app_colors.dart) so that
      // the ~565 existing `AppColors.x` call sites across the app don't need
      // to become context-aware. Keying on themeStyle forces this whole
      // subtree to unmount/remount on toggle, which is what makes those
      // static reads pick up the freshly-applied palette everywhere at once.
      return MaterialApp.router(
        key: ValueKey(themeStyle),
        title: 'ThrottleIQ',
        theme: AppTheme.build(themeStyle),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      );
    } catch (e) {
      print('App initialization error: $e');
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error: $e'),
          ),
        ),
      );
    }
  }
}
