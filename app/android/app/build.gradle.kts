import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.bft.throttleiq"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.bft.throttleiq"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Re-enabled 2026-08-28 after auditing every plugin with native
            // Android code against proguard-rules.pro — several
            // (dev.fluttercommunity.plus.*, com.pravera.*, com.ryanheise.*,
            // etc.) had no keep rule at all despite reflection/native
            // bridging, which is the likely cause of the original crash.
            // Verified on the Pixel_10_Pro emulator: release build launches,
            // reaches the login screen, and Google Sign-In's native flow
            // (MinuteMaidActivity) runs without a FATAL EXCEPTION. NOT yet
            // verified: real hardware, or deeper flows that need a logged-in
            // account (ride recording/auto-tracking foreground service,
            // voice notes, home-screen widgets). See docs/Issues.md.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}



dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.12.0"))

  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")

  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}


