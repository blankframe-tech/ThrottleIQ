import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/auto_tracking_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // dark icons on light paper
    statusBarBrightness: Brightness.light, // iOS: light status bar background
  ));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
}
