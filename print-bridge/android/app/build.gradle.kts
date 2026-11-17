plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val customAppId = (project.findProperty("appId") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("ANDROID_APP_ID")?.takeIf { it.isNotBlank() }
    ?: "com.multitenant.printbridge"

val customAppName = (project.findProperty("appName") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("ANDROID_APP_NAME")?.takeIf { it.isNotBlank() }
    ?: "Thermal Print Bridge"

android {
    namespace = "com.elorigen.printcompanion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
