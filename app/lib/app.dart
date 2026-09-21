import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
import 'features/poi_directory/presentation/providers/places_provider.dart';
import 'features/ride/presentation/providers/auto_tracking_provider.dart';
import 'features/ride/presentation/providers/ride_recording_provider.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/keyboard_dismiss_wrapper.dart';

class ThrottleIQApp extends ConsumerStatefulWidget {
  const ThrottleIQApp({super.key});

  @override
  ConsumerState<ThrottleIQApp> createState() => _ThrottleIQAppState();
}

class _ThrottleIQAppState extends ConsumerState<ThrottleIQApp>
    with WidgetsBindingObserver {
  StreamSubscription<ServiceStatus>? _locationServiceSub;

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

    // Watches the OS location-service toggle. When the rider turns GPS back on
    // after launching the app with it off, all location-dependent providers
    // that entered an error state need to be reset so they retry immediately —
    // otherwise the rider must force-quit and reopen the app.
    //
    // We guard on ServiceStatus.enabled only (not disabled): disabling while
    // the app is open is handled per-screen already (geolocator stream errors),
    // and we don't want to fire redundant invalidations on every status change.
    _locationServiceSub = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled && mounted) {
        _invalidateLocationProviders();
      }
    });
  }

  /// Clears the error state of every provider that depends on device GPS so
  /// they re-run their checks immediately when the service becomes available.
  void _invalidateLocationProviders() {
    ref.invalidate(currentPositionProvider);
    ref.invalidate(nearbyPlacesProvider);
    ref.invalidate(autoTrackingEnabledProvider);
  }

  @override
  void dispose() {
    _locationServiceSub?.cancel();
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
    // A rider who left to revoke (or grant) location permission from OS
    // Settings and comes straight back should see the Settings switch
    // reflect that immediately, not only after they next toggle it — see
    // AutoTrackingNotifier.build for the actual re-check this triggers.
    ref.invalidate(autoTrackingEnabledProvider);
    // Also reset location-dependent providers so the Places tab and any other
    // GPS feature recovers without a restart after the rider enables location.
    _invalidateLocationProviders();
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
          //
          // The owner is saved before the service starts so its very first
          // detection is stamped with this rider (grill §1.4.2).
          final uid = next.valueOrNull!.uid;
          unawaited(AutoTrackingService.setOwner(uid)
              .then((_) => AutoTrackingService.instance.start()));
          unawaited(_reconcileDetectedRides());
        } else {
          sync.stopAutoSync();
          // Stop first, then forget the owner, so nothing detected in between
          // can be stamped with the rider who just signed out.
          unawaited(AutoTrackingService.instance
              .stop()
              .then((_) => AutoTrackingService.setOwner(null)));
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
        builder: (context, child) => _ClampedTextScale(
          child: KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('App initialization error: $e');
      return MaterialApp(
        builder: (context, child) => KeyboardDismissWrapper(
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Center(
            child: Text('Error: $e'),
          ),
        ),
      );
    }
  }
}

/// Caps how far the OS text-size setting can enlarge the app's type.
///
/// Flutter already scales a hardcoded `fontSize` by `MediaQuery.textScaler`,
/// so text *does* grow — but this app has ~535 hardcoded sizes and a lot of
/// fixed-height rows, chips and cockpit tiles, and at the 2.0x+ the platform
/// allows those overflow rather than reflow (issues §83.22).
///
/// 1.3x is the compromise: it is a real, usable enlargement for the rider who
/// needs it, and it is inside what the existing layouts absorb. The floor is
/// there because a scale below 1.0 makes safety-critical cockpit numbers
/// smaller than they were designed to be read at, at speed.
///
/// This is a stopgap, not accessibility support. The layouts should be made
/// scale-tolerant so the clamp can be raised or dropped.
class _ClampedTextScale extends StatelessWidget {
  const _ClampedTextScale({required this.child});

  final Widget child;

  static const _minScale = 1.0;
  static const _maxScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: _minScale,
          maxScaleFactor: _maxScale,
        ),
      ),
      child: child,
    );
  }
}
