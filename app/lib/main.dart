import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/auto_tracking_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

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
      print('Firebase initialization error: $e');
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

    // Prepare the background tracker's config and register its headless task.
    // This does NOT start tracking — AutoTrackingService.start() does, and only
    // if the rider has opted in. Registering the headless task at every launch
    // (not just when enabled) is deliberate: it is how the plugin knows what to
    // invoke after a device reboot, before any Dart of ours has run.
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
