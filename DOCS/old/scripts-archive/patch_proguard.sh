sed -i '' '/-keep class com.google.firebase.\*\* { \*; }/d' app/android/app/proguard-rules.pro
sed -i '' '/-keep class com.google.android.gms.\*\* { \*; }/d' app/android/app/proguard-rules.pro
sed -i '' '/-keep class com.google.android.libraries.\*\* { \*; }/d' app/android/app/proguard-rules.pro
sed -i '' '/-keep class java.util.\*\* { \*; }/d' app/android/app/proguard-rules.pro
sed -i '' '/-keep class \*\* extends ChangeNotifier { \*; }/d' app/android/app/proguard-rules.pro
sed -i '' 's/# Minification is currently OFF in build.gradle.kts/# Minification is ON/g' app/android/app/proguard-rules.pro
