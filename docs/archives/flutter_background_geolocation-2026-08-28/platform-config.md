# Platform config removed alongside `auto_tracking_service.dart`

Everything below was deleted from the app when the paid plugin was swapped
out on 2026-08-28. Restoring the plugin (see this folder's `README.md`) means
putting these back, on top of whatever the free-tier implementation has
since changed in the same files.

## `pubspec.yaml`

```yaml
  flutter_background_geolocation: ^4.16.0
```

(was listed alongside `wakelock_plus` under "Background tracking" — see this
repo's git history for the exact surrounding comment.)

## `android/build.gradle.kts`

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        // flutter_background_geolocation ships its Android AARs inside the
        // plugin directory rather than publishing them to a public Maven
        // repo, so Gradle has to be pointed at them explicitly. Without these
        // two lines the build fails to resolve
        // com.transistorsoft:tslocationmanager and nothing about the error
        // mentions the plugin by name.
        maven(url = "${project(":flutter_background_geolocation").projectDir}/libs")
        // The plugin's background-service dependency chain resolves a Huawei
        // artifact on some configurations; harmless on devices without HMS.
        maven(url = "https://developer.huawei.com/repo/")
    }

    // flutter_background_geolocation's background-service chain pulls
    // androidx.work:work-runtime-ktx:2.7.1, while another plugin resolves
    // plain work-runtime:2.8.1 — same classes, two jars, so the merge fails
    // with "Duplicate class". Forcing both to the newer version keeps a
    // single copy on the classpath.
    configurations.all {
        resolutionStrategy {
            force("androidx.work:work-runtime:2.8.1")
            force("androidx.work:work-runtime-ktx:2.8.1")
        }
    }
}
```

Without this, `flutter build apk` fails immediately with `Project with path
':flutter_background_geolocation' could not be found` — this is the first
thing to restore, before anything else, if bringing the plugin back.

## `android/app/src/main/AndroidManifest.xml`

Inside `<application>`, in place of the free-tier's
`com.pravera.flutter_foreground_task.service.ForegroundService` declaration:

```xml
<!-- flutter_background_geolocation licence key.

     REQUIRED FOR RELEASE BUILDS. Debug builds run unlicensed; a
     release build without a valid key logs a licence error and the
     plugin never starts, which presents as "auto-tracking works on my
     phone but not for testers". Buy at https://shop.transistorsoft.com
     and paste the key below — it is per Android application id
     (com.bft.throttleiq), not per developer.

     The plugin declares its own foreground service, boot receiver and
     headless dispatcher in its library manifest; they are merged in
     automatically and must NOT be re-declared here. -->
<meta-data
    android:name="com.transistorsoft.locationmanager.license"
    android:value="PASTE_LICENCE_KEY_BEFORE_RELEASE" />
```

## `ios/Runner/Info.plist`

`UIBackgroundModes` needs `processing` added back alongside `fetch`, and
`BGTaskSchedulerPermittedIdentifiers` becomes:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.transistorsoft.fetch</string>
    <string>com.transistorsoft.customtask</string>
</array>
```

## `ios/Runner/AppDelegate.swift`

The free-tier's `flutter_foreground_task` import and
`SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback` block should
come back out — `flutter_background_geolocation` does not need an equivalent
registration hook.

## Not archived

`AutoDetectionDao`, the `auto_detections`/`auto_fixes` schema, and
`AutoRideReconcilerService` did not change either direction — both the paid
plugin and the free-tier stand-in write through the same DAO. Nothing to
restore there.
