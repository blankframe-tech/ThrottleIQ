# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core (deferred components) — referenced by the Flutter engine but not
# shipped in this app; suppress the R8 missing-class failure.
-dontwarn com.google.android.play.core.**

# Firestore/Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.libraries.** { *; }
-keep class java.util.** { *; }

# Dart
-keep class com.google.dart.** { *; }

# SQLite
-keep class org.sqlite.** { *; }

# Riverpod/Provider state management
-keep class ** extends ChangeNotifier { *; }

# --- Added while diagnosing a release-only launch crash (2026-07-25) ---
# Minification is currently OFF in build.gradle.kts because this crash was
# never root-caused with an actual device stack trace. These rules are added
# so that whoever re-enables isMinifyEnabled has a real starting point instead
# of the previous partial ruleset (which had nothing for the plugins below,
# several of which use reflection/native bridging and are common R8 victims).
# Get a real crash log (adb logcat, search "FATAL EXCEPTION") before trusting
# this list is complete — it's a reasonable starting point, not a guarantee.

# Geolocator (native location bridging)
-keep class com.baseflow.geolocator.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# io.flutter.plugins.GeneratedPluginRegistrant and any first-party plugin
# actually registered under this namespace (e.g. image_picker above also
# lives here) — the federated fluttercommunity/pravera/etc. plugins below do
# NOT live under this package despite the "plus"/"flutter_" naming, so they
# each need their own rule.
-keep class io.flutter.plugins.** { *; }

# dev.fluttercommunity.plus.* federated plugins: wakelock_plus,
# connectivity_plus, battery_plus, share_plus, sensors_plus, device_info_plus,
# package_info_plus
-keep class dev.fluttercommunity.plus.** { *; }

# flutter_activity_recognition (auto-tracking motion trigger) and
# flutter_foreground_task (auto-tracking's persistent service — the
# ForegroundService class itself is manifest-declared so R8 already treats it
# as an entry point, but its supporting classes are not)
-keep class com.pravera.** { *; }

# record (push-to-talk voice notes)
-keep class com.llfbandit.record.** { *; }

# just_audio + audio_session (push-to-talk playback/routing)
-keep class com.ryanheise.** { *; }

# home_widget (writes the SharedPreferences the app's own AutoTracking/
# RideStats/StartRide/Maintenance widget providers read)
-keep class es.antonborri.home_widget.** { *; }

# vibration
-keep class com.benjaminabel.vibration.** { *; }

# flutter_timezone
-keep class net.wolverinebeach.flutter_timezone.** { *; }

# sqflite (plugin binding — distinct from the org.sqlite native lib above)
-keep class com.tekartik.sqflite.** { *; }

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
