import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/services/auto_tracking_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';
import 'core/utils/bike_image_resolver.dart';

/// Turns on Firebase App Check (issues §83.19).
///
/// App Check attaches an attestation token to every Firestore/Auth/Storage
/// request so the backend can tell the real app from a script using the public
/// API key. It is the only control for request-*volume* abuse: Firestore rules
/// cannot bound volume, which is why the crash-notification fix is idempotency
/// only.
///
/// This is inert until **enforcement** is switched on in the Firebase console,
/// and that switch must wait until a release containing this code is what riders
/// actually run — enforcing earlier locks out every older build (the same
/// ship-the-client-first rule as issues §78.27). Debug builds use the debug
/// provider; its token is printed to the log and has to be registered in the
/// console. A failure here must never stop the app from launching.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e) {
    debugPrint('App Check activation failed (non-fatal): $e');
  }
}

void main() async {
  // Must run before anything else: this registers the port the auto-tracking
  // foreground-service isolate uses to talk back to the UI isolate, and has
  // to exist before that service (possibly already running from before this
  // process started — after a reboot, or the app being relaunched while it
  // was still watching for a ride) can deliver to it.
  FlutterForegroundTask.initCommunicationPort();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(getApplicationDocumentsDirectory().then((dir) {
      BikeImageResolver.cachedDocumentsDirectoryPath = dir.path;
    }).catchError((_) {}));

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // dark icons on light paper
      statusBarBrightness:
          Brightness.light, // iOS: light status bar background
    ));

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _activateAppCheck();
      await AnalyticsService.instance.init();

      // Debug builds report to a "debug" Crashlytics project bucket that
      // nobody watches and just adds noise while iterating locally — only
      // release/profile builds should actually report.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // Flutter framework errors (widget build/layout/paint failures) go
      // through FlutterError.onError, not the zone's error handler.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      // Errors outside Flutter's own error zone (platform channel callbacks,
      // isolate errors) surface here instead of FlutterError.onError.
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }

    // Home-screen widgets: fire-and-forget. Every call inside is no-op safe, so
    // a missing widget extension or launcher never delays or breaks startup.
    unawaited(HomeWidgetService.instance.bootstrap());

    // Notifications have to be initialised before anything can deliver one, and
    // the first thing that might is a crash alert — so this is awaited rather
    // than fired and forgotten. It creates channels and wires the action
    // handlers; it does not ask for permission (see requestPermissions).
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }

    // Declares the background tracker's notification/task options. This does
    // NOT start tracking — AutoTrackingService.start() does, and only if the
    // rider has opted in. Boot survival doesn't depend on this running first:
    // flutter_foreground_task's native side persists the Dart callback handle
    // itself the first time the service is started, and re-invokes it
    // directly on reboot without waiting for this app's main() to run.
    try {
      await AutoTrackingService.instance.configure();
    } catch (e) {
      debugPrint('Auto-tracking configure failed: $e');
    }

    runApp(const ProviderScope(child: ThrottleIQApp()));
  }, (error, stack) {
    // Catches anything thrown outside a Flutter-managed callback (e.g. inside
    // a bare async gap) that neither handler above sees.
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
