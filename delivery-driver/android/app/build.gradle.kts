plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val customAppId = (project.findProperty("appId") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("ANDROID_APP_ID")?.takeIf { it.isNotBlank() }
    ?: "com.multitenant.driver"

val customAppName = (project.findProperty("appName") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("ANDROID_APP_NAME")?.takeIf { it.isNotBlank() }
    ?: "Delivery Driver"

android {
    namespace = "com.elorigen.elorigen_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = customAppId
        manifestPlaceholders["appName"] = customAppName
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
