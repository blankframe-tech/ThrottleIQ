import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/cloud/sync_manager.dart';
import 'core/i18n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/home_widget_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_style_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/ride/presentation/providers/ride_recording_provider.dart';
import 'l10n/app_localizations.dart';

class ThrottleIQApp extends ConsumerStatefulWidget {
  const ThrottleIQApp({super.key});

  @override
  ConsumerState<ThrottleIQApp> createState() => _ThrottleIQAppState();
}

class _ThrottleIQAppState extends ConsumerState<ThrottleIQApp> {
  @override
  void initState() {
    super.initState();
    // Tapping the home-screen "Start ride" widget should land on Record, not
    // just wherever the app happened to be. Registered here rather than in
    // main() because it needs the router, and once (not per rebuild) because
    // the underlying stream would otherwise gain a listener on every frame.
    //
    // Navigating only — it does NOT auto-start recording. Starting a ride
    // without the rider confirming would be a surprising thing for a
    // home-screen tap to do, and the Record screen's slide-to-start gesture
    // exists precisely to make that deliberate.
    HomeWidgetService.instance.registerStartRideHandler(() {
      if (!mounted) return;
      ref.read(routerProvider).go('/home/record');
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Cloud sync lifecycle: start on login, stop on logout. SyncManager itself
      // no-ops when signed out, so starting is safe; stopping avoids idle timers.
      ref.listen(authStateProvider, (prev, next) {
        final sync = ref.read(syncManagerProvider);
        if (next.valueOrNull != null) {
          sync.startAutoSync();
          // Pick up any ride that was still recording when the app last went
          // away (swiped out of recents, killed process — no chance to call
          // stopRide()). It comes back *paused*, for the rider to resume,
          // end, or discard; see
          // RideRecordingNotifier.restoreInterruptedRide. Only meaningful
          // once signed in, since it touches the per-user local ride DB.
          ref.read(rideRecordingProvider.notifier).restoreInterruptedRide();
        } else {
          sync.stopAutoSync();
        }
      });

      final router = ref.watch(routerProvider);
      final themeStyle = ref.watch(themeStyleProvider);
      // null = follow the device language, resolved against supportedLocales.
      final locale = ref.watch(appLocaleProvider);
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
        // Unlike the appearance switch above, a language change needs no
        // remount: Localizations rebuilds its dependents on a locale change,
        // so the key stays keyed on themeStyle alone.
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en'), Locale('bn')],
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
