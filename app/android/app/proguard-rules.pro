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

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
