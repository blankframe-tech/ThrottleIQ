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

# sensors_plus / battery_plus / device_info_plus / package_info_plus (Flutter
# plugin registration classes — safe broad keep for first-party plugin glue)
-keep class io.flutter.plugins.** { *; }

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
