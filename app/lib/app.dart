import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/cloud/sync_manager.dart';
import 'core/i18n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/auto_tracking_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';
import 'features/ride/data/repositories/auto_ride_reconciler_service.dart';
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

class _ThrottleIQAppState extends ConsumerState<ThrottleIQApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Tapping a ride-confirmation notification should land on that ride, so
    // the rider can say which bike it was. Registered once, here, for the same
    // reason as the widget handler below.
    NotificationService.instance.onConfirmRideTapped = (rideId) {
      if (!mounted) return;
      ref.read(routerProvider).go('/ride/summary/$rideId');
    };
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
    // Tapping the "Start Auto-Tracking" widget lands on Settings, where the
    // switch (and, if it fails, the reason why) lives — see
    // AutoTrackingWidgetProvider's doc comment for why this doesn't just flip
    // the switch itself: enabling it needs to survive a location-permission
    // prompt and a possible failure, neither of which has anywhere to surface
    // from a bare launch intent.
    HomeWidgetService.instance.registerAutoTrackingHandler(() {
      if (!mounted) return;
      ref.read(routerProvider).go('/settings');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rides detected while the app was closed are rebuilt the moment it comes
  /// back to the foreground, not only at cold start.
  ///
  /// The common shape is: rider parks, opens the app a minute later to check
  /// something — the process was never killed, so a launch-only hook would sit
  /// on the finished journey until the next cold start, which on a phone that
  /// keeps apps alive could be days.
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState != AppLifecycleState.resumed) return;
    unawaited(_reconcileDetectedRides());
  }

  Future<void> _reconcileDetectedRides() async {
    if (!await AutoTrackingService.isEnabled()) return;
    if (!mounted) return;
    await ref.read(autoRideReconcilerServiceProvider).reconcilePending();
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
          // Auto-tracking is per-rider: it needs a uid to attribute detected
          // rides to, and reconciling before sign-in would have nothing to
          // attach them to. Both no-op unless the rider has opted in.
          unawaited(AutoTrackingService.instance.start());
          unawaited(_reconcileDetectedRides());
        } else {
          sync.stopAutoSync();
          unawaited(AutoTrackingService.instance.stop());
        }
      });

      final router = ref.watch(routerProvider);
      final appearance = ref.watch(appearanceProvider);
      // null = follow the device language, resolved against supportedLocales.
      final locale = ref.watch(appLocaleProvider);
      // AppColors is a mutable static facade (see app_colors.dart) so that
      // the ~565 existing `AppColors.x` call sites across the app don't need
      // to become context-aware. Keying on appearance forces this whole
      // subtree to unmount/remount on toggle, which is what makes those
      // static reads pick up the freshly-applied palette everywhere at once.
      return MaterialApp.router(
        key: ValueKey(appearance),
        title: 'ThrottleIQ',
        theme: AppTheme.build(appearance),
        debugShowCheckedModeBanner: false,
        // Unlike the appearance switch above, a language change needs no
        // remount: Localizations rebuilds its dependents on a locale change,
        // so the key stays keyed on appearance alone.
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
